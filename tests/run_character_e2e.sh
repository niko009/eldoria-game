#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
LOG_DIR="$ROOT/tests/logs"
mkdir -p "$LOG_DIR"
"$GODOT_BIN" --headless --path "$ROOT/client" --editor --quit > "$LOG_DIR/character-import.log" 2>&1
"$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/animated_actor_e2e.gd -- --test > "$LOG_DIR/character-e2e.log" 2>&1
if grep -Ei 'SCRIPT ERROR|Parse Error|ANIMATED ACTOR FAIL' "$LOG_DIR/character-import.log" "$LOG_DIR/character-e2e.log"; then
    exit 1
fi
grep -q 'ANIMATED ACTOR PASS' "$LOG_DIR/character-e2e.log"
echo 'PASS: three rigged KayKit characters, idle/walk/run/cheer, headless server.'
