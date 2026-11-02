using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Npgsql;

var url = Environment.GetEnvironmentVariable("ASPNETCORE_URLS") ?? "http://127.0.0.1:19091";
if (url.Split(';').Any(value => !Uri.TryCreate(value, UriKind.Absolute, out var u)
    || !u.IsLoopback || u.Scheme != Uri.UriSchemeHttp))
    throw new InvalidOperationException("Persistence API must bind to loopback HTTP only.");
var secret = Environment.GetEnvironmentVariable("ELDORIA_INTERNAL_KEY");
var secretFile = Environment.GetEnvironmentVariable("ELDORIA_INTERNAL_KEY_FILE");
if (string.IsNullOrWhiteSpace(secret) && !string.IsNullOrWhiteSpace(secretFile))
    secret = File.ReadAllText(secretFile).Trim();
if (string.IsNullOrEmpty(secret) || secret.Length < 24)
    throw new InvalidOperationException("ELDORIA_INTERNAL_KEY must be at least 24 characters.");
var connectionString = Environment.GetEnvironmentVariable("ELDORIA_POSTGRES_CONNECTION")
    ?? throw new InvalidOperationException("ELDORIA_POSTGRES_CONNECTION is required.");
var connection = new NpgsqlConnectionStringBuilder(connectionString);
var postgresPasswordFile = Environment.GetEnvironmentVariable("ELDORIA_POSTGRES_PASSWORD_FILE");
if (string.IsNullOrWhiteSpace(connection.Password) && !string.IsNullOrWhiteSpace(postgresPasswordFile))
    connection.Password = File.ReadAllText(postgresPasswordFile).Trim();
if (string.IsNullOrEmpty(connection.Password))
    throw new InvalidOperationException("PostgreSQL password is required.");
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
ALTER TABLE eldoria_players ADD COLUMN IF NOT EXISTS axe integer NOT NULL DEFAULT 0 CHECK (axe BETWEEN 0 AND 1);
CREATE TABLE IF NOT EXISTS eldoria_buildings (
    world_seed integer NOT NULL REFERENCES eldoria_worlds(world_seed) ON DELETE CASCADE,
    building_id integer NOT NULL CHECK (building_id BETWEEN 1 AND 100000),
    kind varchar(16) NOT NULL CHECK (kind IN ('campfire', 'tent')),
    pos_x double precision NOT NULL CHECK (pos_x BETWEEN -75 AND 75),
    pos_z double precision NOT NULL CHECK (pos_z BETWEEN -75 AND 75),
    PRIMARY KEY (world_seed, building_id)
);
-- TASK-018: analytics samples only. No player token, IP, identity or device fingerprint.
CREATE TABLE IF NOT EXISTS eldoria_telemetry (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    captured_at timestamptz NOT NULL DEFAULT now(),
    version varchar(24) NOT NULL,
    platform varchar(16) NOT NULL CHECK (platform IN ('android','windows','test')),
    quality varchar(8) NOT NULL CHECK (quality IN ('low','high')),
    fps_avg double precision NOT NULL CHECK (fps_avg BETWEEN 0.5 AND 500),
    fps_low_5 double precision NOT NULL CHECK (fps_low_5 BETWEEN 0.2 AND 500),
    frame_p95_ms double precision NOT NULL CHECK (frame_p95_ms BETWEEN 0.1 AND 2000),
    memory_mb integer NOT NULL CHECK (memory_mb BETWEEN 1 AND 65536),
    rtt_ms integer NOT NULL CHECK (rtt_ms BETWEEN 0 AND 10000),
    samples integer NOT NULL CHECK (samples BETWEEN 60 AND 7200)
);
CREATE INDEX IF NOT EXISTS ix_eldoria_telemetry_recent
    ON eldoria_telemetry(captured_at DESC);
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
await using var source = NpgsqlDataSource.Create(connection.ConnectionString);
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
        "to_regclass('public.eldoria_resources') IS NOT NULL AND " +
        "to_regclass('public.eldoria_buildings') IS NOT NULL", conn);
    if (await verify.ExecuteScalarAsync() is not true)
        throw new InvalidOperationException("Eldoria schema is absent; migrate before starting.");
}

builder.Services.AddHostedService(_ => new TelemetryRetentionWorker(source));
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
        "SELECT identity_hash, avatar, wood, stone, herb, axe FROM eldoria_players WHERE world_seed=@seed", conn, snapshotTx))
    {
        read.Parameters.AddWithValue("seed", seed);
        await using var reader = await read.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
            profiles[reader.GetString(0)] = new ProfileDto(reader.GetInt16(1),
                new InventoryDto(reader.GetInt32(2), reader.GetInt32(3), reader.GetInt32(4), reader.GetInt32(5)));
    }
    var buildings = new Dictionary<string, BuildingDto>();
    await using (var read = new NpgsqlCommand(
        "SELECT building_id, kind, pos_x, pos_z FROM eldoria_buildings WHERE world_seed=@seed", conn, snapshotTx))
    {
        read.Parameters.AddWithValue("seed",seed);
        await using var reader = await read.ExecuteReaderAsync(ct);
        while (await reader.ReadAsync(ct))
            buildings[reader.GetInt32(0).ToString()] = new BuildingDto(reader.GetString(1),reader.GetDouble(2),reader.GetDouble(3));
    }
    await snapshotTx.CommitAsync(ct);
    return Results.Ok(new SnapshotDto(1, seed, revision, depleted, profiles, buildings));
});

app.MapPut("/v1/world/{seed:int}", async (int seed, SnapshotDto? snapshot, CancellationToken ct) =>
{
    if (seed != Seed || snapshot is null || snapshot.schema != 1 || snapshot.world_seed != Seed
        || snapshot.revision < 0 || snapshot.profiles is null || snapshot.depleted is null
        || snapshot.profiles.Count > MaxProfiles || snapshot.depleted.Count > MaxResources
        || (snapshot.buildings?.Count ?? 0) > 300
        || (snapshot.buildings?.Any(pair => !int.TryParse(pair.Key,out var id) || id is < 1 or > 100000
            || pair.Value is null || pair.Value.kind is not ("tent" or "campfire")
            || !double.IsFinite(pair.Value.x) || !double.IsFinite(pair.Value.z)
            || Math.Abs(pair.Value.x) > 75 || Math.Abs(pair.Value.z) > 75) ?? false)
        || snapshot.depleted.Any(kv => !int.TryParse(kv.Key, out var id)
            || id is < 1 or > 100000 || kv.Value is < 0 or > 1000000)
        || snapshot.profiles.Any(kv => !ValidHash(kv.Key) || kv.Value is null
            || kv.Value.avatar is < 0 or > 2 || kv.Value.inventory is null
            || kv.Value.inventory.wood is < 0 or > 1000000
            || kv.Value.inventory.stone is < 0 or > 1000000
            || kv.Value.inventory.herb is < 0 or > 1000000
            || kv.Value.inventory.axe is < 0 or > 1))
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
        "DELETE FROM eldoria_buildings WHERE world_seed=@seed; " +
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
        "INSERT INTO eldoria_players(world_seed,identity_hash,avatar,wood,stone,herb,axe) " +
        "VALUES (@seed,@hash,@avatar,@wood,@stone,@herb,@axe)", conn, tx))
    {
        insert.Parameters.AddWithValue("seed", seed);
        insert.Parameters.Add("hash", NpgsqlTypes.NpgsqlDbType.Varchar);
        insert.Parameters.Add("avatar", NpgsqlTypes.NpgsqlDbType.Smallint);
        insert.Parameters.Add("wood", NpgsqlTypes.NpgsqlDbType.Integer);
        insert.Parameters.Add("stone", NpgsqlTypes.NpgsqlDbType.Integer);
        insert.Parameters.Add("herb", NpgsqlTypes.NpgsqlDbType.Integer);
        insert.Parameters.Add("axe", NpgsqlTypes.NpgsqlDbType.Integer);
        foreach (var pair in snapshot.profiles)
        {
            insert.Parameters["hash"].Value = pair.Key;
            insert.Parameters["avatar"].Value = (short)pair.Value.avatar;
            insert.Parameters["wood"].Value = pair.Value.inventory.wood;
            insert.Parameters["stone"].Value = pair.Value.inventory.stone;
            insert.Parameters["herb"].Value = pair.Value.inventory.herb;
            insert.Parameters["axe"].Value = pair.Value.inventory.axe;
            await insert.ExecuteNonQueryAsync(ct);
        }
    }
    await using (var insert = new NpgsqlCommand(
        "INSERT INTO eldoria_buildings(world_seed,building_id,kind,pos_x,pos_z) " +
        "VALUES (@seed,@id,@kind,@x,@z)", conn, tx))
    {
        insert.Parameters.AddWithValue("seed",seed);
        insert.Parameters.Add("id",NpgsqlTypes.NpgsqlDbType.Integer);
        insert.Parameters.Add("kind",NpgsqlTypes.NpgsqlDbType.Varchar);
        insert.Parameters.Add("x",NpgsqlTypes.NpgsqlDbType.Double);
        insert.Parameters.Add("z",NpgsqlTypes.NpgsqlDbType.Double);
        foreach (var pair in snapshot.buildings ?? new Dictionary<string,BuildingDto>())
        {
            insert.Parameters["id"].Value = int.Parse(pair.Key);
            insert.Parameters["kind"].Value = pair.Value.kind;
            insert.Parameters["x"].Value = pair.Value.x;
            insert.Parameters["z"].Value = pair.Value.z;
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

// Insert-only performance telemetry, intentionally disconnected from player profiles.
// No session ID, token, IP, free-text error messages or personal device details.
app.MapPost("/v1/telemetry", async (TelemetryDto? input, CancellationToken ct) =>
{
    if (input is null || input.version is null || !System.Text.RegularExpressions.Regex.IsMatch(input.version,@"^\d{1,4}\.\d{1,4}\.\d{1,4}$")
        || input.platform is not ("android" or "windows" or "test")
        || input.quality is not ("low" or "high")
        || !double.IsFinite(input.fps_avg) || input.fps_avg is < 0.5 or > 500
        || !double.IsFinite(input.fps_low_5) || input.fps_low_5 is < 0.2 or > 500
        || !double.IsFinite(input.frame_p95_ms) || input.frame_p95_ms is < 0.1 or > 2000
        || input.memory_mb is < 1 or > 65536 || input.rtt_ms is < 0 or > 10000
        || input.samples is < 60 or > 7200)
        return Results.BadRequest(new { error = "invalid_telemetry" });
    await using var conn = await source.OpenConnectionAsync(ct);
    await using var cmd = new NpgsqlCommand("""
        INSERT INTO eldoria_telemetry
        (version, platform, quality, fps_avg, fps_low_5, frame_p95_ms, memory_mb, rtt_ms, samples)
        VALUES (@version,@platform,@quality,@avg,@low,@p95,@memory,@rtt,@samples)
        """,conn);
    cmd.Parameters.AddWithValue("version",input.version);
    cmd.Parameters.AddWithValue("platform",input.platform);
    cmd.Parameters.AddWithValue("quality",input.quality);
    cmd.Parameters.AddWithValue("avg",input.fps_avg);
    cmd.Parameters.AddWithValue("low",input.fps_low_5);
    cmd.Parameters.AddWithValue("p95",input.frame_p95_ms);
    cmd.Parameters.AddWithValue("memory",input.memory_mb);
    cmd.Parameters.AddWithValue("rtt",input.rtt_ms);
    cmd.Parameters.AddWithValue("samples",input.samples);
    await cmd.ExecuteNonQueryAsync(ct);
    return Results.Accepted();
});

app.MapGet("/v1/telemetry/summary", async (CancellationToken ct) =>
{
    var rows = new List<object>();
    await using var conn = await source.OpenConnectionAsync(ct);
    await using var cmd = new NpgsqlCommand("""
        SELECT version, platform, quality, COUNT(*)::bigint AS samples,
            ROUND(AVG(fps_avg)::numeric,1) AS avg_fps,
            ROUND(AVG(fps_low_5)::numeric,1) AS avg_low_fps,
            ROUND(AVG(frame_p95_ms)::numeric,1) AS avg_frame_p95_ms,
            ROUND(AVG(memory_mb)::numeric,0) AS avg_memory_mb,
            ROUND(AVG(rtt_ms)::numeric,0) AS avg_rtt_ms
        FROM eldoria_telemetry
        WHERE captured_at >= now() - interval '14 days'
        GROUP BY version, platform, quality
        ORDER BY samples DESC LIMIT 30
        """,conn);
    await using var reader = await cmd.ExecuteReaderAsync(ct);
    while (await reader.ReadAsync(ct))
        rows.Add(new {
            version=reader.GetString(0),platform=reader.GetString(1),quality=reader.GetString(2),
            reports=reader.GetInt64(3),fps_avg=reader.GetDecimal(4),
            fps_low_5=reader.GetDecimal(5),frame_p95_ms=reader.GetDecimal(6),
            memory_mb=reader.GetDecimal(7),rtt_ms=reader.GetDecimal(8)});
    return Results.Ok(rows);
});

await app.RunAsync();


static bool ValidHash(string hash) =>
    hash.Length == 64 && hash.All(c => c is >= '0' and <= '9' or >= 'a' and <= 'f');

record TelemetryDto(string version, string platform, string quality, double fps_avg,
    double fps_low_5, double frame_p95_ms, int memory_mb, int rtt_ms, int samples);

sealed class TelemetryRetentionWorker(NpgsqlDataSource source) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken token)
    {
        while (!token.IsCancellationRequested)
        {
            try
            {
                await using var conn = await source.OpenConnectionAsync(token);
                await using var cmd = new NpgsqlCommand(
                    "DELETE FROM eldoria_telemetry WHERE captured_at < now() - interval '14 days'", conn);
                await cmd.ExecuteNonQueryAsync(token);
            }
            catch (OperationCanceledException) when (token.IsCancellationRequested) { break; }
            catch (Exception ex) { Console.Error.WriteLine("Eldoria telemetry retention failed: "+ex.GetType().Name); }
            try { await Task.Delay(TimeSpan.FromHours(24), token); }
            catch (OperationCanceledException) { break; }
        }
    }
}

record InventoryDto(int wood, int stone, int herb, int axe = 0);
record ProfileDto(int avatar, InventoryDto inventory);
record BuildingDto(string kind, double x, double z);
record SnapshotDto(int schema, int world_seed, long revision,
    Dictionary<string, int> depleted, Dictionary<string, ProfileDto> profiles,
    Dictionary<string, BuildingDto>? buildings = null);
