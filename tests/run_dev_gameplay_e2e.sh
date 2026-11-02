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
bash tests/run_combat_e2e.sh
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
    DISPLAY=":$display_number" timeout 90 "$GODOT_BIN" --path "$ROOT/client" --resolution 720x360 --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/task017_sound_mobile_e2e.gd -- --test-mobile-ui > "$ROOT/tests/logs/task017-mobile-opengl.log" 2>&1
    grep -q "TASK017 OPENGL PASS" "$ROOT/tests/logs/task017-mobile-opengl.log"
    kill "$xvfb" 2>/dev/null || true
    trap - EXIT
    echo "PASS: real OpenGL MultiMesh resource depletion and restoration"
else
    echo "NOTE: OpenGL visual test skipped: Xvfb not available."
fi
echo "PASS: TASK-011..017 gameplay, WAV sound, staged tree damage, Android build mode, VFX, PostgreSQL compatibility."
