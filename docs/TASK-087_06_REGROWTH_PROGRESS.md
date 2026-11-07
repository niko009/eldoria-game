# TASK-087.06 — partial implementation (not accepted)

Implemented isolated `tree_regrowth.gd` policy: 300-second UTC Unix deadline, deterministic 299/300 boundary and building-footprint check. This is **not yet wired into the game**. No resource will regrow with this commit alone.

Verified Godot 4.5.2 `--headless --editor --import --quit` exit 0 and `--headless --script res://tests/task087_tree_regrowth_policy_e2e.gd` exit 0. No WSS, Android or restart integration was run.

Remaining: persist per-tree UTC deadlines across **both** JSON and PostgreSQL stores with backwards compatibility; record depletion atomically with inventory; server tick with collision/occupied building deferral and authoritative resource snapshots; tests for restart, 299/300, two clients, repeated harvesting, legacy snapshots and Android performance. Existing depleted trees must not suddenly regrow during migration. No production schema change or deployment is authorized.
