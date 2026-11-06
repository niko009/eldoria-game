# TASK-087.09 — HUD audit, phase 1 (no interaction redesign)

Baseline: `feature/TASK-064-wildlife-hud` at `83f8f8d2a9bbfcd45197ae430e3cdb26466f8301`. Godot 4.5.2. No production or gameplay changes.

## Confirmed source observations

- `client/ui/game_hud.gd::_layout()` places status at upper left, resources immediately below it, progression below resources; menu at upper right, hotbar bottom centre, joystick bottom left and combat buttons bottom right. `status_w` is fixed at 210/220 logical px. This makes upper-left status density a real layout constraint, not a measured readability defect.
- `_safe_insets()` uses platform safe area when mobile/test-mobile; on desktop it uses fixed (15,15,15,17). Safe-area behavior on a real notched Android device remains **unverified**.
- `client/ui/live_ui.gd::_layout()` sizes modal dialog at up to 600×540, with mobile top/bottom margins 49/30. `touch_scroll` handles modal dragging. It is not yet verified on actual Android.
- Existing `task032_hud_e2e.gd` asserts no overlap of combat buttons, menu, resources, hotbar, joystick at 1280×720, 1280×576, 800×360 and 640×360. It does not test physical cutouts, finger occlusion or contrast.
- Existing quick consumables and target/spell controls are contextual. Their presence is not proof of ergonomic usability.

## Options for UI approval (not implemented)

1. **Compact tactical HUD (preferred for next prototype):** health/mana + level at upper left, collapse materials to one row; retain existing right-hand action cluster and bottom hotbar. Low risk; most changes are spacing/visual hierarchy.
2. **Minimal exploration HUD:** keep only health, selected tool and interaction hint; reveal resource counters on collection or inventory open. Reduces clutter but hides information and changes interaction expectations.
3. **Configurable HUD:** separate moveable clusters with saved layouts. Most flexible but higher implementation and touch regression risk; should not precede the simpler layout.

## Visual QA matrix and limits

Run `client/tests/task087_hud_audit.gd` under real OpenGL/Xvfb with `--test-mobile-ui`; it captures class 0 and class 2 at 1280×720, 1280×576 and 800×360 into Godot `user://task087-hud-*`. This is a **before-only** geometry and screenshot baseline, not an after comparison. Do not infer actual Android performance or safe-area behavior from these captures.

Before implementation, collect same-position screenshots day/night and open inventory/craft, compare to user's actual Android screenshot and approved concept; capture physical Android safe-area cases and record FPS/occlusion. Implementation must wait for 087.03–087.05 integration and user approval of hotbar interaction method. No automatic merge.
