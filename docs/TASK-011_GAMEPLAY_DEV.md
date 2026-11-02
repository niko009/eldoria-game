# TASK-011 — Gameplay development: avatar selection, jumping, camera and gathering

**Status:** development branch only. **No release was built or published**, no public server/site/config changes. Production remains Eldoria **v0.4.1**. The protocol is intentionally incompatible with the published server.

## What was implemented

### 1. Persisted player character selection
- `client/avatar_profile.gd`: client preference saved in `user://eldoria-profile.cfg`, choices `Knight`, `Rogue_Hooded`, `Mage`. Whitelist validation and default fallback.
- Avatar dropdown in the Godot UI, including Android.
- On join, the client sends the selected avatar ID. The authoritative Godot server validates the ID and includes it in `spawn_remote` RPC; existing peers receive the new player's actual choice, and the new peer receives all existing choices.
- An in-game change broadcasts the validated new selection to connected peers.
- A player's selection survives reconnect **on the same device**. No online account/cross-device identity yet. Distinct server peer IDs still change on reconnect, but selected visual is restored.
- Dedicated server tracks choices without instantiating visual GLB actors.

### 2. Ballistic jump and animation
- `client/jump_motion.gd`: deterministic parabola, 6 m/s initial velocity, 14 m/s² gravity, ~0.857 s total duration, 1.286 m max height.
- Space (Windows) / **Jump** button (Android). The server validates on-ground state and cooldown before broadcasting `jump_started`. Client animates Jump_Start/Jump_Idle/Jump_Land and interpolates root Y; server permits vertical position packets **only** during the allowed jump envelope. Horizontal obstacles remain blocking.
- This is a prototype physics model, not Godot CharacterBody3D rigid-body collision. No double jump/wall jump, no landing sound.

### 3. Chase camera obstacle avoidance
- `forest_world.gd::camera_safe_target`: the camera's line of sight is limited before a trunk, boulder or rising terrain, with adjustable follow interpolation in the main scene.
- Trees/rocks use deterministic approximate circle blockers. Foliage isn't solid; no promise of zero occlusion for all mesh shapes.

### 4. In-memory resources and private inventory
- Resources embedded into the deterministic world: **wood** on trees, **stone** on rocks, **herb** on flower/flower bush/mushrooms; starter plants are within reach of the initial spawn.
- **Gather (F)** on Windows or touch **Gather** button on Android. HUD shows nearest gatherable spot and Wood/Stone/Herbs counts.
- The Godot server validates peer ID, resource ID, available quantity, 2.7m gather distance, elevation and rate limit (280ms) before changing its resource quantity and player's own inventory. Each player gets a private inventory snapshot, all players get authoritative resource depletion.
- A late join receives the full current in-memory resource snapshot. Reconnect restores avatar choice and receives depleted resources, but inventory is **new/empty** (no auth/persistent identity yet).
- The PickUp animation plays on all clients; depleted **herbs disappear from the MultiMesh**, and their transform restores from state. Trees and rocks stay visible/solid after harvesting, until a later world-destruction feature.
- No persistence across server restarts; future PostgreSQL/authoritative .NET work required.

### 5. Explicit release safety
- `main.gd` sets `DEVELOPMENT_BUILD := true`: normal launches neither query production server config nor auto-install updates. UI explicitly exposes **Join localhost (DEV)** and **Host test world (DEV)**.
- The shipping version, public WSS service, site, APK and Windows ZIP remain at **v0.4.1**. Do not flip this constant or publish files until user explicitly approves a release and a new client/server version is negotiated.

## Test matrix

- `tests/run_network_e2e.sh`: 2 ENet peers, motion, disconnect, reconnect — PASS.
- `tests/run_dedicated_e2e.sh`: headless dedicated + 2 independent ENet clients and interactions — PASS.
- `tests/run_websocket_e2e.sh`: headless WebSocket dedicated + 2 independent clients — PASS.
- `tests/run_character_e2e.sh`: imported KayKit animation models + headless mode — PASS.
- `tests/run_avatar_jump_e2e.sh`: independent peers select Rogue/Mage, replicate airborne jump ~1.29m, land — PASS.
- `client/tests/camera_profile_e2e.gd`: camera blockers, clear path, jump arc, server vertical validation, preference persistence — PASS.
- `tests/run_resource_e2e.sh`: each peer collects one herb into own private inventory, shared depletion, invalid IDs rejected; later reconnect receives depleted snapshot and empty new inventory — PASS.
- `client/tests/gather_validation_e2e.gd`: server gathers wood and stone, respects distances, IDs, depletion and inventory counts — PASS.
- `client/tests/render_probe.gd`: **real OpenGL renderer** (Xvfb + Mesa), verify depleted herb MultiMesh is hidden and restored when available — PASS. **Not valid with --headless** (Godot dummy renderer returns identity transforms).
- `client/tests/collision_perf_e2e.gd`, forest / update manifest tests — PASS.

## Known limits

Real Windows and Android hardware were not available for this test cycle; graphical verification only under Linux Mesa and Xvfb. No quantified Android FPS performance; jump/camera controls and screen ergonomics require hands-on mobile test. Server still anonymous, no anti-cheat hardening, durable inventory, resource respawn, inventory trading or building.
