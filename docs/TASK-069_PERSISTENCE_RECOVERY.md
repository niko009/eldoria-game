# TASK-069 — Persistence API recovery & hunting inventory

## Problem confirmed
- Production logs show `Persistence API response timeout` followed by `409 stale_world_revision` after an ambiguous PUT.
- Godot `postgres_world_store.gd` and `world_save.gd` only loaded legacy ten-item inventories.
- The .NET Persistence API and its PostgreSQL schema omitted meat/hide/bone/leather_armor/grilled_meat. Old servers silently discarded newly earned loot on restart.

## Changes
- Additive PostgreSQL migration `sql/005_hunting_inventory.sql` with five zero-default columns; no deletion of existing rows, XP or building state.
- .NET API validates and round-trips all 15 inventory fields, preserving existing JSON contract.
- Godot loaders round-trip all items for PostgreSQL and JSON.
- GET startup retries only transient HTTP statuses / timeouts, never corrupt schema.
- Ambiguous PUT / 409: GET authoritative snapshot; only accept as committed if revision is exactly +1 **and** resources, profiles (all items, avatar, skills), buildings match intended state. Any mismatch fails closed, without overwrite.
- Explicit regression: `bash tests/run_task069_persistence_e2e.sh`; real API/isolated PostgreSQL: `TASK069_API_BINARY=... bash tests/validate_task069_pg_api.sh`.

## Deployment order
1. Check full regression and build API binary; validate on isolated PostgreSQL.
2. Backup production DB via `pg_dump -Fc` and current API executable; verify backup.
3. Stop game server and persistence service, apply **only additive** SQL 005, install new API binary, restart API and verify authenticated health/snapshot.
4. Deploy updated Godot server/Windows/Android clients, verify saves, data and game connection.
5. Do NOT use a production backup restore automatically on any failure. Existing schema additions are backward compatible; revert binary and game service if needed.

## Limitations
- Thread-pool starvation / host overload may still produce timeouts. Bounded retries improve availability but are not a substitute for observability and host capacity.
- A concurrent different writer's 409 must remain a visible failure, not automatic last-write-wins.
