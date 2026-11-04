#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"

cd "$ROOT"
echo "[TASK-011] ENet host/client"
bash tests/run_network_e2e.sh
sleep 1
echo "[TASK-011] dedicated ENet"
bash tests/run_dedicated_e2e.sh
sleep 1
echo "[TASK-011] local WebSocket"
bash tests/run_websocket_e2e.sh
sleep 1
bash tests/run_character_e2e.sh
echo "[TASK-011] avatar + jump"
bash tests/run_avatar_jump_e2e.sh
sleep 1
echo "[TASK-011] authoritative resources"
bash tests/run_resource_e2e.sh
bash tests/run_building_e2e.sh
bash tests/run_craft_network_e2e.sh
echo "[TASK-033] KayKit equipment socket and server-authoritative visual state"
"$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task033_equipment_e2e.gd -- --test \
    > "$ROOT/tests/logs/task033-equipment.log" 2>&1
grep -q 'TASK033 EQUIPMENT PASS' "$ROOT/tests/logs/task033-equipment.log"
bash tests/run_combat_e2e.sh
echo "[TASK-039] cooperative preparation/night defense/medic rewards"
"$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task039_camp_raid_e2e.gd -- --test-live-ui \
    > "$ROOT/tests/logs/task039-camp-raid.log" 2>&1
grep -q 'TASK039 CAMP RAID PASS' "$ROOT/tests/logs/task039-camp-raid.log"
"$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task039_raid_faults_e2e.gd -- --test-live-ui \
    > "$ROOT/tests/logs/task039-raid-faults.log" 2>&1
grep -q 'TASK039 RAID FAULTS PASS' "$ROOT/tests/logs/task039-raid-faults.log"
bash tests/run_raid_network_e2e.sh
echo "[TASK-030] Android modal swipe and tap"
"$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/android_modal_scroll_e2e.gd -- --test-live-ui \
    > "$ROOT/tests/logs/android-modal-scroll.log" 2>&1
grep -q 'ANDROID_MODAL_SCROLL_E2E PASS' "$ROOT/tests/logs/android-modal-scroll.log"
echo "[TASK-032] mobile HUD layout and actions"
"$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task032_hud_e2e.gd -- --test-live-ui \
    > "$ROOT/tests/logs/task032-hud.log" 2>&1
grep -q 'TASK032 MOBILE HUD PASS' "$ROOT/tests/logs/task032-hud.log"
bash tests/run_telemetry_e2e.sh
# Stone axe crafting persists across real Godot host restarts.
TMP_AXE=$(mktemp -d)
ELDORIA_SAVE_PATH="$TMP_AXE/world.json" "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/craft_axe_e2e.gd -- --initial
ELDORIA_SAVE_PATH="$TMP_AXE/world.json" "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/craft_axe_e2e.gd -- --restored
rm -rf "$TMP_AXE"
"$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/craft_axe_faults_e2e.gd -- --test \
    > "$ROOT/tests/logs/craft-axe-faults.log" 2>&1
grep -q 'CRAFT AXE FAULTS PASS' "$ROOT/tests/logs/craft-axe-faults.log"
TEMP_COMBAT=$(mktemp -d)
ELDORIA_SAVE_PATH="$TEMP_COMBAT/world.json" "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/first_combat_e2e.gd -- --test \
    > "$ROOT/tests/logs/first-combat.log" 2>&1
grep -q 'COMBAT FIRST LOOP PASS' "$ROOT/tests/logs/first-combat.log"
rm -rf "$TEMP_COMBAT"
"$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/building_ui_e2e.gd -- --test
echo "[TASK-015] terrain depletion persists across real dedicated server restarts"
TEMPDIR=$(mktemp -d)
trap 'rm -rf "$TEMPDIR"' EXIT
ELDORIA_SAVE_PATH="$TEMPDIR/world.json" "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/forest_depletion_persistence_e2e.gd -- --initial
ELDORIA_SAVE_PATH="$TEMPDIR/world.json" "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/forest_depletion_persistence_e2e.gd -- --restored
rm -rf "$TEMPDIR"
trap - EXIT
echo "[TASK-012] Android analogue joystick + durable server saves"
"$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/joystick_e2e.gd -- --test
bash tests/run_persistence_e2e.sh

for test_name in camera_profile_e2e gather_validation_e2e collision_perf_e2e forest_update_e2e; do
    "$GODOT_BIN" --headless --path "$ROOT/client" --script "res://tests/$test_name.gd" -- --test
done
echo "[TASK-037] collision grid vs legacy full obstacle scan: movement and camera parity"
"$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task037_collision_benchmark.gd -- --test \
    > "$ROOT/tests/logs/task037-collision-benchmark.log" 2>&1
grep -q 'TASK037 COLLISION PARITY PASS' "$ROOT/tests/logs/task037-collision-benchmark.log"

if command -v Xvfb >/dev/null 2>&1; then
    display_number=91
    while [ -e "/tmp/.X11-unix/X$display_number" ]; do
      display_number=$((display_number + 1))
    done
    Xvfb ":$display_number" -screen 0 800x600x24 -nolisten tcp >"$ROOT/tests/logs/resource-opengl-xvfb.log" 2>&1 &
    xvfb=$!
    trap 'kill "$xvfb" 2>/dev/null || true' EXIT
    sleep 0.5
    DISPLAY=":$display_number" timeout 30 "$GODOT_BIN" --path "$ROOT/client" --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/render_probe.gd -- --test >"$ROOT/tests/logs/resource-opengl.log" 2>&1
    grep -q "RESOURCE OPENGL VISUAL PASS" "$ROOT/tests/logs/resource-opengl.log"
    DISPLAY=":$display_number" timeout 30 "$GODOT_BIN" --path "$ROOT/client" --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/joystick_gui_e2e.gd -- --test > "$ROOT/tests/logs/joystick-opengl.log" 2>&1
    grep -q "JOYSTICK GUI PASS" "$ROOT/tests/logs/joystick-opengl.log"
    DISPLAY=":$display_number" timeout 32 "$GODOT_BIN" --path "$ROOT/client" --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/forest_resource_visual_e2e.gd -- --test > "$ROOT/tests/logs/forest-resource-opengl.log" 2>&1
    grep -q "FOREST RESOURCE OPENGL PASS" "$ROOT/tests/logs/forest-resource-opengl.log"
    DISPLAY=":$display_number" timeout 90 "$GODOT_BIN" --path "$ROOT/client" --resolution 900x550 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/visual_feedback_e2e.gd -- --test > "$ROOT/tests/logs/visual-feedback-opengl.log" 2>&1
    grep -q "VISUAL FEEDBACK OPENGL PASS" "$ROOT/tests/logs/visual-feedback-opengl.log"
    echo "[TASK-034] buildings and visual construction effects on real OpenGL"
    DISPLAY=":$display_number" timeout 95 "$GODOT_BIN" --path "$ROOT/client" --resolution 900x550 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/task034_building_vfx_e2e.gd -- --test > "$ROOT/tests/logs/task034-building-opengl.log" 2>&1
    grep -q "TASK034 BUILDING OPENGL PASS" "$ROOT/tests/logs/task034-building-opengl.log"
    echo "[TASK-035] interaction animations and bounded resource reward markers"
    DISPLAY=":$display_number" timeout 95 "$GODOT_BIN" --path "$ROOT/client" --resolution 900x550 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/task035_interaction_e2e.gd -- --test > "$ROOT/tests/logs/task035-interaction-opengl.log" 2>&1
    grep -q "TASK035 INTERACTION OPENGL PASS" "$ROOT/tests/logs/task035-interaction-opengl.log"
    echo "[TASK-056] real OpenGL: server-confirmed damage sparks, damage numbers and wolf animation"
    DISPLAY=":$display_number" timeout 95 "$GODOT_BIN" --path "$ROOT/client" --resolution 800x600 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/task056_combat_vfx_e2e.gd -- --test > "$ROOT/tests/logs/task056-combat-opengl.log" 2>&1
    grep -q "TASK056 COMBAT VFX OPENGL PASS" "$ROOT/tests/logs/task056-combat-opengl.log"
    DISPLAY=":$display_number" timeout 90 "$GODOT_BIN" --path "$ROOT/client" --resolution 720x360 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/task017_sound_mobile_e2e.gd -- --test-mobile-ui > "$ROOT/tests/logs/task017-mobile-opengl.log" 2>&1
    grep -q "TASK017 OPENGL PASS" "$ROOT/tests/logs/task017-mobile-opengl.log"
    kill "$xvfb" 2>/dev/null || true
    trap - EXIT
    echo "PASS: real OpenGL MultiMesh resource depletion and restoration"
else
    echo "NOTE: OpenGL visual test skipped: Xvfb not available."
fi
echo "PASS: TASK-011..017 gameplay, WAV sound, staged tree damage, Android build mode, VFX, PostgreSQL compatibility."

echo "[TASK-050] permanent combat bonuses and progression UI"
for script in task050_skill_balance_e2e task050_skills_ui_e2e; do
    "$GODOT_BIN" --headless --path "$ROOT/client" --script "res://tests/$script.gd" \
        > "$ROOT/tests/logs/$script.log" 2>&1
    grep -q 'TASK050 .* PASS' "$ROOT/tests/logs/$script.log"
done
bash tests/run_task050_skills_network_e2e.sh
sleep 1
echo "[TASK-051] shield defender aggro, cooldown and team visibility"
"$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task051_shield_taunt_e2e.gd \
    > "$ROOT/tests/logs/task051-shield-e2e.log" 2>&1
grep -q 'TASK051 SHIELD TAUNT PASS' "$ROOT/tests/logs/task051-shield-e2e.log"
bash tests/run_task051_shield_network_e2e.sh
echo "PASS: TASK-050..051 server-authoritative teamplay, XP benefits and Android skill UI."
echo "[TASK-052] three hero classes, campfire switch and server-owned abilities"
"$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task052_hero_classes_e2e.gd \
    > "$ROOT/tests/logs/task052-hero-classes.log" 2>&1
grep -q 'TASK052 HERO CLASSES PASS' "$ROOT/tests/logs/task052-hero-classes.log"
bash tests/run_task052_classes_network_e2e.sh
echo "PASS: TASK-052 Knight/Rogue/Mage abilities and two-client validation."
echo '[TASK-053] crafted weapons usable from live UI and imported wildlife'
"$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task053_crafted_weapons_ui_e2e.gd -- --test-live-ui \
    > "$ROOT/tests/logs/task053-craft-equip.log" 2>&1
grep -q 'TASK053 CRAFTED WEAPONS UI PASS' "$ROOT/tests/logs/task053-craft-equip.log"
"$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task053_wildlife_models_e2e.gd \
    > "$ROOT/tests/logs/task053-wildlife.log" 2>&1
grep -q 'TASK053 WILDLIFE MODELS PASS' "$ROOT/tests/logs/task053-wildlife.log"
bash tests/run_bow_network_e2e.sh
echo 'PASS: TASK-053 equipment hotbar/rucksack/authoritative combat and wildlife GLB.'
echo '[TASK-054] bow/spear combat clarity and icon inventory/crafting'
"$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task054_combat_icons_e2e.gd -- --test-live-ui \
    > "$ROOT/tests/logs/task054-combat-icons.log" 2>&1
grep -q 'TASK054 COMBAT ICONS PASS' "$ROOT/tests/logs/task054-combat-icons.log"
echo 'PASS: TASK-054 server-facing melee, bow feedback and icon UI.'
echo '[TASK-055] directional gathering, selection highlight and cross-platform zoom'
"$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task055_targeting_zoom_e2e.gd -- --test-live-ui \
    > "$ROOT/tests/logs/task055-targeting-zoom.log" 2>&1
grep -q 'TASK055 TARGETING ZOOM PASS' "$ROOT/tests/logs/task055-targeting-zoom.log"
echo 'PASS: TASK-055 directional gathering, Android pinch, desktop wheel and aim indicators.'
