# TASK-005 — Eldoria public internet multiplayer (2026-11-01)

## Architecture

Windows x64 / Android ARM64 (one Godot scene, same game logic) → HTTPS `https://bacus.dev/projects/eldoria/server.json` → WSS `wss://bacus.dev/eldoria/ws` → Cloudflare Tunnel → Caddy route `/eldoria/ws` → Godot WebSocketMultiplayerPeer headless service `eldoria-ws-test.service` on `172.18.0.1:7788`.

No public UDP forwarding required. Existing LAN ENet UDP 7777 service remains separate for compatibility and tests. Both protocols reuse the same GDScript world and RPCs. Client auto-selects protocol from server.json. Version 0.1.3 required for WSS.

## Live deployment

- Website: `https://bacus.dev/projects/eldoria/`.
- Config: `https://bacus.dev/projects/eldoria/server.json`.
- Game endpoint: `wss://bacus.dev/eldoria/ws`.
- Server: `sudo systemctl status eldoria-ws-test.service`.
- Reverse proxy: Caddy route `@eldoriaWs` in `/srv/bacus/infra/caddy/Caddyfile`, backend `172.18.0.1:7788`.
- Limit: 10 concurrent connections (best effort in GDScript); no user accounts or persistence.

## Verification

- `bash tests/run_network_e2e.sh` PASS.
- `bash tests/run_dedicated_e2e.sh` PASS.
- `bash tests/run_websocket_e2e.sh` PASS (headless server + two independent Godot clients, movement, Wave, disconnect/rejoin).
- On deployed bacus-server: two independent Godot clients connected over the **public Cloudflare WSS endpoint**, replicated movement, Wave and reconnect PASS.
- On deployed bacus-server: public HTTPS discovery → WSS → avatar spawn PASS.
- Export Windows 0.1.3 ZIP and Android 0.1.3 debug APK PASS; downloaded again from public site and SHA-256 verified.
- **Not verified:** Windows .exe on real Windows hardware, Android APK on physical Android, remote mobile data connection from a different ISP.
- **Not production-safe:** no authentication, anti-cheat, authority hardening, persistence, abuse protection or capacity tests. This is a public **pre-alpha test**; do not treat as production MMO.

## Deployment caveats

Caddyfile is bind-mounted into Docker; if edited using atomic replacement, Docker retains the old inode until the Caddy container is recreated. Validate and run `docker compose -f /srv/bacus/infra/caddy/compose.yml up -d --no-deps --force-recreate caddy` to bind new file; confirm the public WSS handshake using a Godot client.

Cloudflare/Caddy must support WebSocket upgrade. HTTP GET to WSS URL without an upgrade may return 404; this does not establish WS availability. Verify via actual Godot WebSocket client.
