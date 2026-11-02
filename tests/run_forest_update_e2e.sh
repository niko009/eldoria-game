#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
"$GODOT_BIN" --headless --path "$ROOT/client" --editor --quit > /tmp/eldoria-forest-import.log 2>&1
"$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/forest_update_e2e.gd -- --test > /tmp/eldoria-forest-update-e2e.log 2>&1
grep -q "FOREST LAYOUT PASS" /tmp/eldoria-forest-update-e2e.log
grep -q "UPDATE MANIFEST VALIDATION PASS" /tmp/eldoria-forest-update-e2e.log
cat /tmp/eldoria-forest-update-e2e.log
echo 'PASS: forest visuals & update manifest logic'
