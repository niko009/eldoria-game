# Eldoria — first playable network spike

Status: experimental prototype, not a released game.

## Run on PC
Install Godot 4.5.2 standard (GDScript). Open `client/project.godot` and press F6/F5. Start one instance with **Host world** and another with **Join world**. For the second instance on the same computer use `127.0.0.1`; on a LAN use the host's private IPv4 address. Network transport: UDP port **7777** (allow inbound UDP in the host firewall). WASD moves; onscreen directional buttons are provided for touch.

## Current scope
Procedural placeholder flat terrain, trees, capsule characters, third-person elevated camera, ENet host/client and movement replication. No dedicated server, persistence, authentication, combat, authoritative movement validation, 3D models, Android APK, or public hosting yet. The host is a player; host disconnect ends the session. The current movement validation is deliberately minimal and not production-safe.

## Next gates
1. Run two real desktop instances and verify join, motion, disconnect and reconnect.
2. Set up Android export templates + SDK and build signed debug APK; test touch UI and performance on a real device.
3. Implement dedicated authoritative server, reconciliation/interpolation and persistent world state before opening internet access.
4. Replace placeholder visuals with licensed assets and generated terrain.

The bacus.dev Eldoria page intentionally keeps the APK download disabled until an actual build is verified.

**2026-11-01 update:** a reproducible **headless** two-process ENet test with movement, disconnect and reconnect was added. See [TASK-001_VERIFICATION.md](TASK-001_VERIFICATION.md). This does not constitute a visual desktop test or a physical Android device test.
