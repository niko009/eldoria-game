# TASK-095 — server revive policy (partial)

This commit introduces an isolated deterministic eligibility/hold policy and
tests. **It is not wired into gameplay and does not implement player rescue.**

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