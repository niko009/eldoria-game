# TASK-047 — Aim-driven bow with authoritative world obstruction

Development branch `feature/TASK-040-multi-wolf-coop`. **No release, no deployment, no production branch changes.**

## Implemented

- Bow input now uses the same camera yaw/pitch on Windows (right mouse look) and Android (right-side touch look). The attack RPC carries a normalized aim direction, not an enemy ID or a client-claimed hit.
- Dedicated server derives arrow origin from the authoritative player position; validates bow ownership, live player, unit direction, elevation bounds, attack cooldown and arrow inventory. A valid fired arrow consumes one unit **even on a miss**; persistence failure refuses the shot and rolls back inventory.
- Server ray-tests wolves and picks the first intersected enemy within 6m. Active tree/rock obstacles and procedural terrain block shots; removed trees no longer block. Other players are not damage targets (no friendly fire).
- The server broadcasts the cosmetic moving arrow tracer to other clients and applies damage itself. A centered bow reticle appears only while the local player has the bow equipped and the modal is closed. Tooltip shows remaining arrows.
- Existing melee attacks, spear, shields, raid rewards and inventory ownership are preserved.

## Verified

- `client/tests/task047_aimed_bow_e2e.gd`: invalid aim, misses, correct target, active tree blocking, removed tree allowing hit, ammunition exhaustion.
- `tests/run_bow_network_e2e.sh`: dedicated WebSocket + two real independent headless clients; attacker sends a miss and an aimed hit; both receive damage state; ammunition ownership stays isolated.
- Existing TASK-043 weapons, TASK-039 coop raid networking, TASK-046 crafting UI and Android-size scroll regressions.

## Remaining

This is a **server-authoritative ray hit** with a visually interpolated tracer, not a simulated ballistic arrow or gravity. Shot direction is sent by the client and is not yet verified against a server-known facing angle. Buildings do not currently occlude arrows; trees/rocks/terrain do. A minor WebSocket closing-state log may still appear on client disconnect. Physical Android playtesting is required before eventual release; visual reticle alignment and gameplay balance need device feedback.
