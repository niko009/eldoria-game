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
    kill "$xvfb" 2>/dev/null || true
    trap - EXIT
    echo "PASS: real OpenGL MultiMesh resource depletion and restoration"
else
    echo "NOTE: OpenGL visual test skipped: Xvfb not available."
fi
echo "PASS: TASK-011/012 offline gameplay, joystick and persistence regressions. No production deployment."
