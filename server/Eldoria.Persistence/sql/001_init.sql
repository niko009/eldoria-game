-- TASK-013 Eldoria world persistence; run on a dedicated Eldoria database.
-- Same tables as guarded AUTO_MIGRATE=1 startup in development.
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

CREATE TABLE IF NOT EXISTS eldoria_buildings (
    world_seed integer NOT NULL REFERENCES eldoria_worlds(world_seed) ON DELETE CASCADE,
    building_id integer NOT NULL CHECK (building_id BETWEEN 1 AND 100000),
    kind varchar(16) NOT NULL CHECK (kind IN ('campfire', 'tent')),
    pos_x double precision NOT NULL CHECK (pos_x BETWEEN -75 AND 75),
    pos_z double precision NOT NULL CHECK (pos_z BETWEEN -75 AND 75),
    PRIMARY KEY (world_seed, building_id)
);

CREATE TABLE IF NOT EXISTS eldoria_resources (
    world_seed integer NOT NULL REFERENCES eldoria_worlds(world_seed) ON DELETE CASCADE,
    resource_id integer NOT NULL CHECK (resource_id BETWEEN 1 AND 100000),
    remaining integer NOT NULL CHECK (remaining BETWEEN 0 AND 1000000),
    PRIMARY KEY (world_seed, resource_id)
);
