#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export ELDORIA_SAVE_PATH="$TMP/world.json"
for phase in initial restored; do
  "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task079_full_loop_e2e.gd -- --test-live-ui "--$phase" > "$TMP/$phase.log" 2>&1 || { cat "$TMP/$phase.log"; exit 1; }
  if grep -E 'ERROR:|SCRIPT ERROR|Parse Error|TASK079 FULL LOOP FAIL' "$TMP/$phase.log"; then exit 1; fi
  grep -q "TASK079 FULL LOOP ${phase^^} PASS" "$TMP/$phase.log" || { cat "$TMP/$phase.log"; exit 1; }
  echo "PASS TASK079 $phase"
done