# TASK-095 — server revive: policy + tested feature branch

**Status 2026-11-08:** New feature code integrated on an isolated branch
from production v0.5.28. Automated server, UI and two-WebSocket-client
tests pass. **Not deployed; not DONE until physical Android acceptance.**

The server now owns a 12-second cooperative downed window, a 1.8-second
hold-to-revive action and 30 HP on rescue. Solo respawn remains four seconds;
hold eligibility uses authoritative health, positions, distance and collision
obstacles, and movement/damage/menu interruption is enforced. Remote clients
receive downed and health snapshots; late joiners get the existing downed state.

Tests: `task095_revive_policy_e2e.gd`, `task095_revive_server_e2e.gd`,
`task095_revive_ui_e2e.gd`, and
`tests/run_task095_revive_network_e2e.sh`. All PASS in isolated Godot tests.

Open: physical Android hold gesture, reconnection/race acceptance, richer
downed animations, and user balancing. See
`docs/audits/TASK-087_090_095_FOLLOWUP_20261108.md`.

## Historical policy-only spike (v0.5.27)

The original v0.5.27 commit introduced only an isolated deterministic policy.
It was **not** wired into gameplay until this subsequent feature branch.

Provisional values: 12-second downed window, 1.8-second uninterrupted hold,
2.5-meter range, 30 HP on successful rescue. These are tuning candidates, not
approved balance values. The live game currently respawns dead players after
four seconds; integration must explicitly change that behavior only for
eligible cooperative teammates, retaining solo respawn.

Before marking DONE: implement server-owned downed state, authoritative LOS
raycast, hold initiation/cancel validation, attack interruption, rescue and
normal respawn transitions; replicate status to both clients, test solo and
two-client WSS, reconnect/death races, and Android touch. Never award XP/loot
for a rescue request without an authoritative event. No DB migration planned.