#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
ELDORIA_SAVE_PATH="$TMP_DIR/world.json" "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task049_skills_persistence_e2e.gd -- --initial >"$TMP_DIR/initial.log" 2>&1
ELDORIA_SAVE_PATH="$TMP_DIR/world.json" "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task049_skills_persistence_e2e.gd -- --restored >"$TMP_DIR/restored.log" 2>&1
grep -q 'TASK049 SKILLS INITIAL PASS' "$TMP_DIR/initial.log"
grep -q 'TASK049 SKILLS RESTORED PASS' "$TMP_DIR/restored.log"
if grep -E 'SCRIPT ERROR|Parse Error|TASK049 SKILLS FAIL' "$TMP_DIR"/*.log; then exit 1; fi
echo 'TASK049 SKILLS PERSISTENCE PASS: stable anonymous identity, inventory, three skills across restart'
