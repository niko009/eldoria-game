# TASK-003 — one Godot client, Windows + Android

Status: **implementation in progress** (2026-11-01).

## Confirmed stage A
- Source of truth: `client/Main.tscn` + `client/main.gd` (shared world and ENet protocol).
- PC: WASD relative to camera; right-mouse drag rotates third-person camera; F11 toggles fullscreen; windowed resolutions selectable.
- Android: same movement/gameplay code; bottom-left touch directions, right-half drag to orbit camera, Wave touch button, low/high visual-quality selector.
- Visual quality is client-side (foliage mesh tessellation + shadows). World objects have the same locations.
- Interaction: server validates the requesting peer and reliably broadcasts Wave state. This is an observable prototype action, not inventory/combat.
- Dedicated Godot 4.5.2 host: `godot --headless --path client -- --dedicated-server`, UDP 7777. It never creates an avatar. Can later replace transport/authority with .NET; **current .NET server is not built**.
- Original `bash tests/run_network_e2e.sh`: PASS (two Godot processes, movement, disconnect, reconnect).
- New `bash tests/run_dedicated_e2e.sh`: PASS (one headless server + two independent Godot clients; movement, interactions, disconnect and reconnect).
- These tests use Linux Godot 4.5.2 processes speaking the same wire protocol; **Windows binary, Android device and actual Windows↔Android interoperability are not yet hardware-tested**.

## Remaining gates
1. Export Windows x86_64 .exe + .pck in ZIP; validate PE and manifest and launch on Windows if available.
2. Export Android ARM64 debug APK with signed package checks.
3. Verify distribution URLs (HTTP, Content-Length, sha256), publish both download controls.
4. On hardware: Windows PC and Android connect simultaneously to the **same reachable** UDP 7777 server. Without an exposed UDP endpoint, use a local LAN host; Cloudflare Tunnel HTTP does not itself forward ENet UDP.
