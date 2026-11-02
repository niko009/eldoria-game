# TASK-018 — Performance telemetry / diagnostic analytics (DEV ONLY)

**Status:** developed and tested, not released. Public Windows/Android clients, live Godot WSS server, .NET persistence service and PostgreSQL **remain v0.5.1**.

## Signal path
Windows / Android Godot → performance sample every ~60 seconds → `submit_telemetry` reliable RPC → **authoritative** Godot dedicated server (validates player & metrics, 45-second per-peer cooldown + 30/min global limit) → bounded async HTTPRequest queue (10 max) → **private loopback** `POST /v1/telemetry` authenticated by server-only key → .NET 10 / Npgsql → `eldoria_telemetry` in PostgreSQL 16.

Failure to send metrics never interrupts gameplay. Game server does not block a frame waiting for the API. Clients cannot contact PostgreSQL or the private API.

Collected fields: client version, broad platform `windows|android|test`, graphics `low|high`, average FPS, 5-percent low FPS (from 95th-percentile frame time), p95 frame time ms, process memory MB, round-trip latency ms (via RPC ping/pong), number of sampled frames. Sampling is aggregated; **no raw player identifier, token, IP address, name, messages, account, precise location, freeform log text or hardware fingerprint** in the saved telemetry.

Under Privacy, a `Performance data: ON/OFF` toggle controls reports. Setting saved locally in `user://eldoria-telemetry.cfg`; turning OFF clears buffered frame samples. Only reports while connected. Does not affect existing gameplay, saves, inventory or movement.

## Database
- `server/Eldoria.Persistence/sql/002_telemetry.sql` adds `eldoria_telemetry` with strict numeric CHECKs and date index. Run separately for production deployment; no modification to world/player/building data.
- `POST /v1/telemetry` validates all fields and returns **202**. Without internal server key -> **401**; invalid -> **400**.
- `GET /v1/telemetry/summary` (private key required) returns aggregated last 14 days grouped by platform, graphics, version. No per-user records. Use this for FPS comparisons.
- A .NET BackgroundService removes rows older than **14 days** daily without touching player data.

### Query examples
```sql
SELECT platform,quality,version,count(*) AS reports,
       round(avg(fps_avg)::numeric,1) AS average_fps,
       round(avg(fps_low_5)::numeric,1) AS low_5_percent_fps,
       round(avg(frame_p95_ms)::numeric,1) AS p95_ms,
       round(avg(memory_mb)::numeric,0) AS memory_mb,
       round(avg(rtt_ms)::numeric,0) AS rtt_ms
FROM eldoria_telemetry
WHERE captured_at > now() - interval '7 days'
GROUP BY platform,quality,version
ORDER BY reports DESC;
```

## Evidence
- `bash tests/run_telemetry_e2e.sh` PASS: real Godot ENet client → Godot dedicated server → internal async HTTP mock. Two identical reports + invalid report produce exactly **one** delivered report. Client sampling, p95/FPS, opt-out and no private fields PASS.
- `bash tests/run_postgres_e2e.sh` on separate PostgreSQL 16 PASS: authenticated insert, negative validation, 14-day aggregated summary, no identifying fields, plus existing transactional world persistence tests. A later **full Godot-to-real-Postgres end-to-end test** was attempted but its first run exposed an invalid Godot HTTPRequest property; the property was corrected and full Godot→HTTP was subsequently retested against the mock. Do not claim a subsequent full real-Postgres Godot-to-SQL test was run until verified.
- `bash tests/run_dev_gameplay_e2e.sh` PASS: ENet/WebSocket, character animation, movement, Android joystick, resource depletion, building and OpenGL.
- No production deployment or actual Android/Windows runtime performance measurement yet.

**Next step:** release compatible client + server + private .NET API with SQL migration (after permission); obtain 1–3 days of actual usage; compare Android Low/High FPS and frame p95 to select specific performance optimizations.
