# TASK-042 — Expanded cooperative crafting (local only)

Base `feature/TASK-040-multi-wolf-coop` with TASK-041. No deploy or release.

- Two new server-authoritative stackable consumables (20 max): `bandage` (1 wood, 2 herbs), restores 40 player HP anywhere; `repair_kit` (3 wood, 2 stone), restores 60 camp HP during the raid within four metres of a campfire. Both crafted within four metres of a campfire.
- Recipes and use actions surfaced in the live crafting panel; quantity synced in personal inventories. Existing axe crafting remains untouched.
- All resource deductions are validated and persisted by dedicated server before acknowledging inventory; failed persistence restores the old inventory and profile copy. No new PostgreSQL columns or API shape needed: existing inventory dictionary is extended with two keys.
- Tests: `client/tests/task042_crafting_e2e.gd` PASS, TASK-041 camp integrity PASS, dedicated WebSocket test with two clients PASS. New recipe server calls are tested, but separate network consumable E2E / actual Android UI interaction have not yet been exercised.

Next: network E2E for simultaneous crafting and race conditions; improve workshop layout for small Android screens and add combat equipment beyond consumables.
