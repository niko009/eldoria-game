# TASK-001 — Godot ENet verification (2026-11-01)

## Reproducible test

On Linux with Godot **4.5.2 standard** installed:

```bash
GODOT_BIN=/path/to/Godot_v4.5.2-stable_linux.x86_64 bash tests/run_network_e2e.sh
```

Uses **two independent Godot engine processes**, real ENet UDP traffic on `127.0.0.1:7777` and actual loaded `Main.tscn`. It checks:

1. Headless Godot editor import without parse errors.
2. Two players connect to the same scene, with consistent initial 3D coordinates.
3. Both players move and observe the other's movement (>1 world unit).
4. Client disconnect removes actor on host and resets the client session.
5. **Same running client process reconnects** and both players move again.
6. Exit codes are zero and logs contain no Godot `ERROR` / `SCRIPT ERROR` / `E2E FAIL`.

Logs are kept under ignored `tests/logs/`. This is automated headless networking, **not** a rendered desktop/phone visual test or a hardware performance test.

## Changes and limits

- Fixed wrong player height on replicated spawn: actor's position is already its capsule centre.
- Added reliable despawn notification, session cleanup, and a disconnect action.
- Stopped position RPCs when the peer is no longer connected.
- Anchored mobile movement controls to the bottom-left instead of placing them below the viewport.
- The host still acts as a player; no persistent server, authentication, reconciliation, interpolation or production-safe movement validation yet.
- No claim of 10 concurrent players, network latency tolerance, full LAN/Internet compatibility or Android device support is made based on this test.

## Additional hardware gate

Install a debug APK on a real Android device, join a host via LAN IP, validate touch events, rendering, background/resume, FPS/memory/thermal behaviour. This gate requires a physical device and remains distinct from headless desktop testing.