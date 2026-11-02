# TASK-019 — v0.5.2 Production Release: Performance Telemetry

2 November 2026. Authorized by user. No new crafting gameplay included in this release.

- Windows x64 ZIP, Android ARM64 signed debug APK versionCode **13**, versionName **0.5.2**; Android SHA256 signing certificate identical to v0.5.1.
- Production private .NET persistence API updated to support the authenticated `/v1/telemetry` endpoint and read-only aggregated `/v1/telemetry/summary`. `401` without server key, `200` with key.
- `server/Eldoria.Persistence/sql/002_telemetry.sql` applied to PostgreSQL 16, isolated `eldoria_telemetry` table. Migration leaves profiles/buildings/resources unchanged. Automatic 14-day deletion of old telemetry.
- Godot WSS v0.5.2 deployed and live. 2 public clients successfully exchanged movement, Wave, reconnect. Additional anonymous test client sent a telemetry report via **public Cloudflare WSS**, server sent private HTTP to .NET, real PostgreSQL row verified, aggregated summary returned version=0.5.2, platform=test, quality=low, fps_avg=48.2, p95 frame time=33.2ms. This one report is **synthetic** and is NOT evidence of real-device FPS.
- Backups before change: `/srv/bacus/backups/eldoria-pre-052-20261102/` includes prior v0.5.1 game, internal API binary, service config, HTML/manifest, and verified PostgreSQL `pg_dump -Fc`.
- Windows ZIP: `Eldoria-Windows-0.5.2.zip`, SHA256 `9c092b17d8222a12173152fb7a7705829cb6601d9ca9d3e413973d609ea04ab7`, 42,826,924 bytes.
- Android APK: `Eldoria-0.5.2-debug.apk`, SHA256 `2dc0c5297820e1858234cb622743a9e01cd9207b22443cf445a73942da859db8`, 36,904,913 bytes.
- Both releases published to `https://bacus.dev/projects/eldoria/` and manifest `latest.json`; public `server.json` protocol requires 0.5.2. Old clients must update.

### Rollback

1. Keep PostgreSQL volume and all world data. Old API executable and game server are backed up at path above.
2. Restore v0.5.1 Godot service override and binary, previous private API, and public HTML/manifest/server.json from the backup. Keep `eldoria_telemetry` table as-is; it does not affect old world tables.
3. Restart and verify both private service and WSS. Do not blindly restore old database dump over current progress.

### Limitations

Physical Android and Windows performance has not been measured by automation. Real average/p95 FPS will become meaningful only after users install v0.5.2 and play for over a minute with telemetry enabled. Avoid making optimization claims before seeing actual samples.
