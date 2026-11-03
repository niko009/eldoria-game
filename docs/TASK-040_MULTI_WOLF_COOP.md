# TASK-040 — Simultaneous cooperative raiders (development)

Base: `release/eldoria-v0.5.10`. No production deployment.

- At night start, the dedicated server creates two additional wolves with stable IDs 1 and 2, alongside the legacy wolf. Each has independent HP, position, direction, aggro and attack cooldown.
- The server chooses a living nearby player per enemy; clients receive authoritative snapshots. Late join receives each additional wolf's current state.
- Melee attacks select the nearest alive enemy within three metres, validated on the server. A defeated wolf contributes once to the existing four-kill night goal; the existing reward path remains unchanged.
- The pack is removed at the end of the night. The existing single-wolf path remains for compatibility with TASK-039 tests.
- No persistence schema or anonymous profile changes. The raid remains ephemeral across server restarts.

Validation: Godot 4.5.2 headless import; TASK-039 deterministic raid test; dedicated WebSocket network E2E with two independent clients (two additional visual actors, independent pack HP and defeat, shared victory and per-player rewards). Android FPS and physical device testing remain outstanding.

Next: add late-join/reconnect and packet-loss regression specifically for the pack; then introduce camp HP, enemy building damage and repair. Avoid production release before those tests and Android measurements.
