using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Npgsql;

var url = Environment.GetEnvironmentVariable("ASPNETCORE_URLS") ?? "http://127.0.0.1:19091";
if (url.Split(';').Any(value => !Uri.TryCreate(value, UriKind.Absolute, out var u)
    || !u.IsLoopback || u.Scheme != Uri.UriSchemeHttp))
    throw new InvalidOperationException("Persistence API must bind to loopback HTTP only.");
var secret = Environment.GetEnvironmentVariable("ELDORIA_INTERNAL_KEY");
if (string.IsNullOrEmpty(secret) || secret.Length < 24)
    throw new InvalidOperationException("ELDORIA_INTERNAL_KEY must be at least 24 characters.");
var connectionString = Environment.GetEnvironmentVariable("ELDORIA_POSTGRES_CONNECTION")
    ?? throw new InvalidOperationException("ELDORIA_POSTGRES_CONNECTION is required.");
const int Seed = 20261101;
const int MaxProfiles = 5000;
const int MaxResources = 5000;
const long MaxBytes = 4 * 1024 * 1024;
const string SchemaSql = """
CREATE TABLE IF NOT EXISTS eldoria_worlds (
    world_seed integer PRIMARY KEY,
    revision bigint NOT NULL DEFAULT 0 CHECK (revision >= 0),
    updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS eldoria_players (
    world_seed integer NOT NULL REFERENCES eldoria_worlds(world_seed) ON DELETE CASCADE,
    identity_hash varchar(64) NOT NULL CHECK (length(identity_hash) = 64),
    avatar smallint NOT NULL CHECK (avatar BETWEEN 0 AND 2),
    wood integer NOT NULL DEFAULT 0 CHECK (wood BETWEEN 0 AND 1000000),
    stone integer NOT NULL DEFAULT 0 CHECK (stone BETWEEN 0 AND 1000000),
    herb integer NOT NULL DEFAULT 0 CHECK (herb BETWEEN 0 AND 1000000),
    PRIMARY KEY (world_seed, identity_hash)
);
CREATE TABLE IF NOT EXISTS eldoria_resources (
    world_seed integer NOT NULL REFERENCES eldoria_worlds(world_seed) ON DELETE CASCADE,
    resource_id integer NOT NULL CHECK (resource_id BETWEEN 1 AND 100000),
    remaining integer NOT NULL CHECK (remaining BETWEEN 0 AND 1000000),
    PRIMARY KEY (world_seed, resource_id)
);
""";
var builder = WebApplication.CreateBuilder(args);
builder.WebHost.UseUrls(url);
builder.Logging.AddFilter("Microsoft.AspNetCore", LogLevel.Warning);
builder.WebHost.ConfigureKestrel(opts => opts.Limits.MaxRequestBodySize = MaxBytes);
await using var source = NpgsqlDataSource.Create(connectionString);
await using (var conn = await source.OpenConnectionAsync())
{
    if (Environment.GetEnvironmentVariable("ELDORIA_DB_AUTO_MIGRATE") == "1")
    {
        await using var migrate = new NpgsqlCommand(SchemaSql, conn);
        await migrate.ExecuteNonQueryAsync();
    }
    await using var verify = new NpgsqlCommand(
        "SELECT to_regclass('public.eldoria_worlds') IS NOT NULL AND " +
        "to_regclass('public.eldoria_players') IS NOT NULL AND " +
        "to_regclass('public.eldoria_resources') IS NOT NULL", conn);
    if (await verify.ExecuteScalarAsync() is not true)
        throw new InvalidOperationException("Eldoria schema is absent; migrate before starting.");
}

var app = builder.Build();
app.Use(async (ctx, next) =>
{
    var got = ctx.Request.Headers["X-Eldoria-Server-Key"].ToString();
    if (got.Length != secret.Length ||
        !CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(got), Encoding.UTF8.GetBytes(secret)))
    {
        ctx.Response.StatusCode = 401;
        return;
    }
    await next();
});

app.MapGet("/health", async (CancellationToken ct) =>
{
    try
    {
        await using var conn = await source.OpenConnectionAsync(ct);
        await using var cmd = new NpgsqlCommand("SELECT 1", conn);
        await cmd.ExecuteScalarAsync(ct);
        return Results.Ok(new { database = "ready" });
    }
    catch { return Results.StatusCode(503); }
});

app.MapGet("/v1/world/{seed:int}", async (int seed, CancellationToken ct) =>
{
    if (seed != Seed) return Results.BadRequest(new { error = "unknown_world" });
    await using var conn = await source.OpenConnectionAsync(ct);
    await using (var init = new NpgsqlCommand(
        "INSERT INTO eldoria_worlds(world_seed) VALUES (@seed) ON CONFLICT DO NOTHING", conn))
    {
        init.Parameters.AddWithValue("seed", seed);
        await init.ExecuteNonQueryAsync(ct);
    }

    // A single repeatable-read snapshot avoids mixing old profile rows with
    // new resource rows while another dedicated server commits a PUT.
    await using var snapshotTx = await conn.BeginTransactionAsync(System.Data.IsolationLevel.RepeatableRead, ct);
    long revision;
    await using (var readRevision = new NpgsqlCommand(
        "SELECT revision FROM eldoria_worlds WHERE world_seed=@seed", conn, snapshotTx))
    {
        readRevision.Parameters.AddWithValue("seed", seed);
        revision = (long)(await readRevision.ExecuteScalarAsync(ct) ?? throw new InvalidOperationException("Missing world"));
    }
    var depleted = new Dictionary<string, int>();
    await using (var read = new NpgsqlCommand(
        "SELECT resource_id,remaining FROM eldoria_resources WHERE world_seed=@seed", conn, snapshotTx))
    {
        read.Parameters.AddWithValue("seed", seed);
        await using var reader = await read.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
            depleted[reader.GetInt32(0).ToString()] = reader.GetInt32(1);
    }
    var profiles = new Dictionary<string, ProfileDto>();
    await using (var read = new NpgsqlCommand(
        "SELECT identity_hash, avatar, wood, stone, herb FROM eldoria_players WHERE world_seed=@seed", conn, snapshotTx))
    {
        read.Parameters.AddWithValue("seed", seed);
        await using var reader = await read.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
            profiles[reader.GetString(0)] = new ProfileDto(reader.GetInt16(1),
                new InventoryDto(reader.GetInt32(2), reader.GetInt32(3), reader.GetInt32(4)));
    }
    await snapshotTx.CommitAsync(ct);
    return Results.Ok(new SnapshotDto(1, seed, revision, depleted, profiles));
});

app.MapPut("/v1/world/{seed:int}", async (int seed, SnapshotDto? snapshot, CancellationToken ct) =>
{
    if (seed != Seed || snapshot is null || snapshot.schema != 1 || snapshot.world_seed != Seed
        || snapshot.revision < 0 || snapshot.profiles is null || snapshot.depleted is null
        || snapshot.profiles.Count > MaxProfiles || snapshot.depleted.Count > MaxResources
        || snapshot.depleted.Any(kv => !int.TryParse(kv.Key, out var id)
            || id is < 1 or > 100000 || kv.Value is < 0 or > 1000000)
        || snapshot.profiles.Any(kv => !ValidHash(kv.Key) || kv.Value is null
            || kv.Value.avatar is < 0 or > 2 || kv.Value.inventory is null
            || kv.Value.inventory.wood is < 0 or > 1000000
            || kv.Value.inventory.stone is < 0 or > 1000000
            || kv.Value.inventory.herb is < 0 or > 1000000))
        return Results.BadRequest(new { error = "invalid_world_snapshot" });

    await using var conn = await source.OpenConnectionAsync(ct);
    await using var tx = await conn.BeginTransactionAsync(ct);
    long actual;
    await using (var lockWorld = new NpgsqlCommand(
        "SELECT revision FROM eldoria_worlds WHERE world_seed=@seed FOR UPDATE", conn, tx))
    {
        lockWorld.Parameters.AddWithValue("seed", seed);
        var result = await lockWorld.ExecuteScalarAsync(ct);
        if (result is null)
        {
            await tx.RollbackAsync(ct);
            return Results.Conflict(new { error = "missing_world" });
        }
        actual = (long)result;
    }
    if (actual != snapshot.revision)
    {
        await tx.RollbackAsync(ct);
        return Results.Conflict(new { error = "stale_world_revision", revision = actual });
    }
    await using (var clear = new NpgsqlCommand(
        "DELETE FROM eldoria_resources WHERE world_seed=@seed; " +
        "DELETE FROM eldoria_players WHERE world_seed=@seed", conn, tx))
    {
        clear.Parameters.AddWithValue("seed", seed);
        await clear.ExecuteNonQueryAsync(ct);
    }
    await using (var insert = new NpgsqlCommand(
        "INSERT INTO eldoria_resources(world_seed,resource_id,remaining) VALUES (@seed,@id,@remaining)", conn, tx))
    {
        insert.Parameters.AddWithValue("seed", seed);
        insert.Parameters.Add("id", NpgsqlTypes.NpgsqlDbType.Integer);
        insert.Parameters.Add("remaining", NpgsqlTypes.NpgsqlDbType.Integer);
        foreach (var pair in snapshot.depleted)
        {
            insert.Parameters["id"].Value = int.Parse(pair.Key);
            insert.Parameters["remaining"].Value = pair.Value;
            await insert.ExecuteNonQueryAsync(ct);
        }
    }
    await using (var insert = new NpgsqlCommand(
        "INSERT INTO eldoria_players(world_seed,identity_hash,avatar,wood,stone,herb) " +
        "VALUES (@seed,@hash,@avatar,@wood,@stone,@herb)", conn, tx))
    {
        insert.Parameters.AddWithValue("seed", seed);
        insert.Parameters.Add("hash", NpgsqlTypes.NpgsqlDbType.Varchar);
        insert.Parameters.Add("avatar", NpgsqlTypes.NpgsqlDbType.Smallint);
        insert.Parameters.Add("wood", NpgsqlTypes.NpgsqlDbType.Integer);
        insert.Parameters.Add("stone", NpgsqlTypes.NpgsqlDbType.Integer);
        insert.Parameters.Add("herb", NpgsqlTypes.NpgsqlDbType.Integer);
        foreach (var pair in snapshot.profiles)
        {
            insert.Parameters["hash"].Value = pair.Key;
            insert.Parameters["avatar"].Value = (short)pair.Value.avatar;
            insert.Parameters["wood"].Value = pair.Value.inventory.wood;
            insert.Parameters["stone"].Value = pair.Value.inventory.stone;
            insert.Parameters["herb"].Value = pair.Value.inventory.herb;
            await insert.ExecuteNonQueryAsync(ct);
        }
    }
    await using (var update = new NpgsqlCommand(
        "UPDATE eldoria_worlds SET revision=revision+1,updated_at=now() WHERE world_seed=@seed", conn, tx))
    {
        update.Parameters.AddWithValue("seed", seed);
        await update.ExecuteNonQueryAsync(ct);
    }
    await tx.CommitAsync(ct);
    return Results.Ok(new { revision = actual + 1 });
});
await app.RunAsync();

static bool ValidHash(string hash) =>
    hash.Length == 64 && hash.All(c => c is >= '0' and <= '9' or >= 'a' and <= 'f');

record InventoryDto(int wood, int stone, int herb);
record ProfileDto(int avatar, InventoryDto inventory);
record SnapshotDto(int schema, int world_seed, long revision,
    Dictionary<string, int> depleted, Dictionary<string, ProfileDto> profiles);
