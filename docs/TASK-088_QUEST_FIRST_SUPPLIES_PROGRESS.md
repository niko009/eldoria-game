# TASK-088 / A-06 — First Supplies quest: first integrated slice

**2026-11-08 — Status: IN_PROGRESS; feature branch `feature/TASK-088-quest-first-supplies`, not deployed.** Based on PR #53 (co-op rescue). This is **one complete starter objective**, not the full QUEST-01 engine and not chapter TASK-098.

## Playable slice

- Explicit, server-owned personal `quest_id=first_supplies`: gather 3 wood + 2 stone from the existing forest.
- Quest state `active → completed → claimed`; compact live HUD progress and one **Получить награду** button; class-based XP (knight defense, rogue archery, mage magic) and +2 herb. Values are provisional balance.
- Only successfully committed authoritative **gather** operations count; non-gather or malformed client data cannot directly award XP or resources. Server validates claim by authenticated RPC sender, accepted stage, inventory/XP room, and persists profile/inventory/skills together.
- Idempotent `claimed`: retries, duplicate clicks and reconnect cannot pay twice. JSON and PostgreSQL persistence share schema-1 optional per-profile `quests` extension.
- Old player profiles with no quest data retain their inventories and receive the **initial** quest state with zero progress; *no retroactive credit*.
- Separate-player co-op sessions retain **private** progress/rewards; this is not a party/shared quest (TASK-094 remains TODO).

## Verification

- Godot 4.5.2 --headless --editor --quit PASS.
- `dotnet build server/Eldoria.Persistence/Eldoria.Persistence.csproj` PASS (0 warnings/errors).
- `task088_starter_quest_policy_e2e.gd`: invalid / overflow / duplicate / prerequisites PASS.
- `tests/run_task088_starter_quest_e2e.sh`: isolated JSON 3-process initial→claim→restart PASS, including forced save failure rollback.
- `tests/run_task088_starter_quest_wss_e2e.sh`: dedicated WebSocket host + 2 distinct clients PASS; one player claims twice, only their XP/items change.
- `client/tests/task088_starter_quest_hud_e2e.gd` under real Godot OpenGL/Xvfb: **six screenshot/geometry captures PASS** at 800×360 and 1280×720 for active, completed and claimed states; the quest prompt and Claim button are contained in the status panel. JPEG samples of actual 800×360 Godot UI: [active](audits/quest-088/800x360-active.jpg), [claim ready](audits/quest-088/800x360-completed.jpg), [claimed](audits/quest-088/800x360-claimed.jpg).
- PostgreSQL end-to-end: **NOT_VERIFIED until a test on an isolated PG database is recorded.**
- Physical Android/Windows graphical interaction: NOT_VERIFIED. Non-production, no user-world migration.

## Production prerequisites — do not apply automatically

1. Backup production PostgreSQL; verify `pg_restore -l`. Apply additive `server/Eldoria.Persistence/sql/013_starter_quests.sql` to the **correct** database; leave existing rows as `{}`.
2. Deploy matching .NET Persistence API with `quests` JSONB read/write/validation **before** starting the new Godot dedicated server. Old API would silently lose quest progress.
3. Publish new dedicated WS server and Android/Windows clients together after isolated PostgreSQL, two-client WSS and touch HUD acceptance. `/usr/local/bin/eldoria-release` does not automatically deploy the Persistence API; a Godot-only release is unsafe.
4. Backup and verify 5 legacy profiles unchanged; failed migration/API update must roll back the API before switching games.

## Remaining A-06 / TASK-093

- Multi-stage quest definitions (craft, build, exploration, combat), versioned data and full quest journal; party scope and earned personal rewards TASK-094/TASK-100.
- Reconnect and lost-ACK PostgreSQL replay tests, legitimate full-inventory failure UI, server logs, physical Android joystick/claim UI, actual 5–10 minute playtest and subsequent 25–40 minute chapter.
- No new NPC, artwork, loot economy or irreversible design choice approved.
