# TASK-046 — Crafting priority and HUD ready-counter

Development branch: `feature/TASK-040-multi-wolf-coop`. No release or deployment.

## Behavior

- Workshop places recipes with **sufficient ingredients and free inventory capacity** first, retaining the catalog order within the ready and unavailable groups.
- A green numeric badge is displayed over the quick-menu crafting icon when one or more distinct recipes have sufficient materials. It disappears when none are ready.
- Badge and highlighted cards respond to the shared inventory change event, including live server inventory snapshots, crafting costs, and ingredient collection.
- Crafting still **requires proximity to a campfire**. The badge counts materials-ready recipes even when a player is away from the station; its tooltip explains this.
- Stack limits prevent already-owned unique equipment and full consumable stacks from being advertised as ready. The live craft request now uses the same shared availability check as the panel.
- The inventory panel shows materials and consumables as read-only entries; only the axe selection is actionable there. This also prevents unwanted unequip when swiping over materials on Android. Other gear and consumables are equipped/used through the crafting menu.
- No changes to server RPCs, persistent inventory schema, recipes, pricing, or production.

## Verification

- `client/tests/task046_crafting_sort_badge_e2e.gd`: ready-first order, numeric HUD badge, live changes, cap handling.
- `client/tests/task045_recipe_highlight_e2e.gd`: highlighting.
- `client/tests/live_ui_smoke.gd`: live inventory adapter updates badge, updated typed craft signal.
- `client/tests/android_modal_scroll_e2e.gd`: Android-sized touch gestures through settings/inventory/build/crafting, short tap preserved.
- Existing crafting, combat and dedicated two-client WebSocket regression suite.

Physical Android device interaction and rendering remain unverified until a later planned release.