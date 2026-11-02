# TASK-012 — Mobile analogue joystick and opt-in durable server save

**Status: DEVELOPMENT ONLY. Do not publish APK/Windows builds or change the public game service until user explicitly approves. Public Eldoria stays v0.4.1.**

## Android input

- `client/mobile_joystick.gd`: an original lightweight left-thumb **analogue virtual joystick** (not four separate D-pad buttons).
- The Control is anchored in the lower-left corner. A 70-pixel input radius, 11% radial deadzone, diagonal movement and full 360° travel generate a continuous normalized `Vector2`. At half deflection, movement is slower.
- First touch inside joystick area captures a single index. A second finger can independently rotate the camera on the right side of the viewport. Dragging beyond the control bounds clamps at full speed; release resets the axis. Session disconnect also resets.
- Drawing uses simple circles/arcs (no UI textures or external dependencies). Move input feeds the existing shared Godot `platform_input.gd` and unchanged character movement, physics and networking.
- Android action buttons Sprint, Gather, Jump and Wave remain. Desktop keyboard/mouse remains unchanged. The old direction helper methods remain in code only for compatibility with legacy input tests, but the four on-screen direction buttons are removed.
- In DEV mode, the connection form shows an editable test-server IPv4/hostname; real devices cannot reach localhost on the Windows PC by using their own loopback.

## Persistent world (prototype; NOT PostgreSQL yet)

- `client/world_save.gd` implements an **opt-in** Godot dedicated-server save using JSON schema 1 and world seed 20261101.
- The server must be explicitly launched with `ELDORIA_SAVE_PATH=/absolute/path/world.json`. Without this env var no files are written, which keeps existing tests and the public v0.4.1 deployment unchanged.
- The client persists a **random 256-bit bearer identity** in `user://eldoria-profile.cfg` (created by Godot Crypto). The secret is sent to the server only on connect; the server persists only its SHA-256 digest. Invalid or duplicate simultaneous identities are rejected or run as transient legacy sessions.
- In the same identity across reconnects or server restarts: inventory (wood/stone/herb), selected avatar and depleted resource quantities are restored. The whole world remains authoritative; clients cannot supply inventory counts.
- Snapshot stored after each resource gather and avatar change, via temporary file, flush and atomic rename. Server explicitly rejects invalid JSON, world schema/seed, invalid quantities, malformed profiles or oversized snapshots rather than silently resetting a world.
- A player's persistent token remains on *that installation*. **Not an account system**: reinstall/removal of app data loses access, stolen tokens can impersonate players, authentication/secret rotation, backups, PostgreSQL and transaction semantics remain future work.
- Full world persistence must be migrated to a robust server datastore before public launch. Synchronous JSON rewriting every pickup is not suitable for large numbers of players.

### Dedicated local test server

```bash
# Example only: isolated DEV save folder, never reuse production state.
ELDORIA_SAVE_PATH=/tmp/eldoria-dev-save/world.json \
  Godot_v4.5.2-stable_linux.x86_64 --headless --path client -- --dedicated-server
```

Dev client connects to the test server IP/port 7777 in the DEV form. Existing Godot WSS local tests continue to work; **do not** connect these modified clients to the live v0.4.1 server.

## Test evidence

- `client/tests/joystick_e2e.gd`: full vector, multi-touch identity, deadzone, maximum radius, release, disconnect — PASS.
- `client/tests/joystick_gui_e2e.gd`: **real** Godot OpenGL/Xvfb GUI touch/drag event routing, second finger and touch release outside bounds — PASS. This is not a physical Android test.
- `tests/run_persistence_e2e.sh`: starts a real dedicated server, client authenticates with test identity, selects Mage and harvests herb; kills server, restarts from same JSON, reconnects with same identity and verifies restored inventory/avatar/depleted resource; sends replayed collection request and verifies **no duplicate**; corrupts snapshot and verifies server **fails closed** — PASS.
- `tests/run_dev_gameplay_e2e.sh`: TASK-011 base gameplay regression and TASK-012 tests (ENet, WSS, two independent players, jumps, resource synchronization, forest collider, OpenGL render).
- **Unverified:** physical Android touch ergonomics/safe areas and actual FPS, Windows install/update on hardware, high-concurrency persistent storage, back-up recovery and malicious client penetration testing.
