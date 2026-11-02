# TASK-021B — Live UI integration (v0.5.3 candidate)

Status: integrated on development branch `feature/TASK-021B-ui-integration`. Production deployment is a separate gate.

## Origin
- Based on `feature/TASK-021-ui-preview` at `fb451a6`; the unfinished TASK-020 axe code is intentionally **not** merged.
- v0.5.2 is still the last established server/public release before deployment.
- New live adapter: `client/ui/live_ui.gd`, rendered through `client/main.gd` only in actual clients (never dedicated server). Offline preview scene remains available.

## Functional wiring
- Real inventory quantities use authoritative `inventory_snapshot`; startup starts at zero, no fake stock.
- HUD reports connection state and chosen hero, hotbar selection is UI-only, no fictitious equipment.
- New touch joystick connects to existing `input_driver.set_joystick`; touch Gather/Jump/Sprint invoke existing actions.
- Building shows real campfire and tent cost; buttons use existing authoritative server-building request. Separate `Показать место` enables the existing green/red placement preview.
- Axe recipe remains explicitly disabled in live mode, since TASK-020 is unmerged and has not had its PostgreSQL migration.
- Settings expose reconnect, disconnect, quality, sound, telemetry, character and building preview.
- Gameplay movement is blocked while modal open; joystick is reset to zero. Original developer UI remains in scene for test harnesses but is hidden in shipped clients.
- No changes to RPC signatures, persistent database schema or private .NET API.

## Checks
- `Godot 4.5.2 --headless --editor --quit`: PASS, no parser errors.
- `client/tests/live_ui_smoke.gd -- --test-live-ui`: PASS with real Main scene, no production network.
- `bash tests/run_dev_gameplay_e2e.sh`: PASS (ENet two-client, WebSocket, characters, physics, resources, buildings, joystick, persistence, visual checks).
- Build and publish checks: see release record, do not infer PASS from source only.
- **Not verified:** touch on physical Android, real-device FPS and visual layout on real hardware.

## Release gate
- Protocol discovery uses strict `client_version` equality. For 0.5.3, publish version-matched Godot dedicated client source and update public `server.json` atomically with public manifest/APK/ZIP.
- No SQL migrations for this UI-only release. Keep current PostgreSQL and .NET service untouched.
- Ensure staging WSS pair tests before production; backup live service/manifest/public artifacts; verify hashes, HTTPS, health, reconnect; rollback file/service changes without restoring database.
- A published build must not be called live until the real server and public manifest are updated and verified.
