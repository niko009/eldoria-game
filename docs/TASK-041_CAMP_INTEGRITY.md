# TASK-041 — Camp defense / repair (local development)

Base: TASK-040 on `feature/TASK-040-multi-wolf-coop`. No release or production changes.

- The earliest campfire becomes the raid objective, with 120 ephemeral HP per night. When no living player is inside a pack wolf's 14m aggro radius, it advances toward that camp and deals 9 damage per 1.8 seconds. No building records are removed.
- Two players share the camp health via server-authoritative RPC; late join receives current HP. At 0 HP, the raid immediately ends in defeat/intermission and active wolves are cleared.
- Repair near a campfire during the night: 2 wood and 1 stone, restore up to 30 HP; 2-second per-player cooldown. The server validates life, range, phase, cost and camp condition. Resource deduction is rolled back on persistence failure. Android/desktop live HUD exposes the action when near the camp with enough resources; keyboard `R` is also available.
- Camp HP is intentionally session-only: no changes to persistence schema, no modifications to saved building records or anonymous identity format.
- Tests: `client/tests/task041_camp_integrity_e2e.gd` PASS (damage, per-enemy cooldown, payment, repair cooldown, loss), prior TASK-039 gameplay PASS and dedicated WebSocket + two independent clients PASS.

## Limitations and next step

This is the first camp HP gameplay slice, not complete building destruction. Pack wolves currently prioritize any living player within 14m, and only attack the camp when nobody is within their aggro range. The legacy wolf continues its player-focused AI. There is no barricade yet and no independent camps. UI visibility and device performance need physical Android validation before a release. Add end-to-end network cases with both players directly repairing and observing damage/loss, then expand tactical pressure (barricades, camp-priority AI) and user-facing victory/defeat feedback.
