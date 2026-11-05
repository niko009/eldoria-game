#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export ELDORIA_SAVE_PATH="$TMP/world.json"
for phase in initial restored; do
  timeout 40 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task081_two_profiles_e2e.gd -- --test-live-ui "--$phase" > "$TMP/$phase.log" 2>&1 || { cat "$TMP/$phase.log"; exit 1; }
  grep -q "TASK081 TWO PROFILES ${phase^^} PASS" "$TMP/$phase.log" || { cat "$TMP/$phase.log"; exit 1; }
  if grep -E 'SCRIPT ERROR|Parse Error|TASK081 TWO PROFILES FAIL' "$TMP/$phase.log"; then exit 1; fi
  echo "TASK081 $phase PASS"
done