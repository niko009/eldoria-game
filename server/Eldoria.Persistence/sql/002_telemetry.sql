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
-- Run daily from a local timer/cron. Do not silently delete player progress.
DELETE FROM eldoria_telemetry WHERE captured_at < now() - interval '14 days';
