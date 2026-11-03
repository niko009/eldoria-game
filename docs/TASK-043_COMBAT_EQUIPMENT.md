# TASK-043 — Combat crafting, local development (no release)

Added server-authoritative recipes and equipment: spear (3 wood + 2 stone, 4.5m, 30 damage), bow (4 wood + 2 herbs, 6m, 20 damage, 1 arrow per successful hit), shield (4 wood + 1 stone, 40% wolf damage reduction), arrow (1 wood + 1 stone, 1 per craft). Crafting requires proximity to an existing campfire. Spear/bow/shield are unique (max 1), arrows stack to 40. Personal inventory persists in the existing dictionary; equipped combat mode remains session-only and is not yet a visible character weapon model.

The workshop now lists these recipes, and lets players equip spear, bow, and shield through the 'Equip' button. Unarmed and old axe systems remain independent. Server verifies ownership, distance, attack cooldown and inventory before applying combat effects. Bow ammo is saved before damage; on persistence failure the shot is refused and ammo restored.

Validation: Godot 4.5.2 import PASS, task043_weapons_e2e PASS (recipe uniqueness, spear reach/damage, bow ammunition, shield mitigation), task042 crafting PASS, task039 two independent websocket clients PASS. Physical Android UI/visual weapon models and end-to-end two-player remote weapon-use are NOT verified. No production deployment.

Next: introduce proper equipped tool UI and synchronized visible weapon models, move aim/line-of-sight to server-validated ranged targeting, and run dedicated two-client combat E2E plus Android Low measurements. This is an early tactical combat increment, not finished ranged physics.
