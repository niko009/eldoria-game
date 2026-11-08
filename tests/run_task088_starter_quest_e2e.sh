#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
godot="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
for phase in initial claim verify; do
  ELDORIA_SAVE_PATH="$tmp/world.json" timeout 50 "$godot" --headless --path "$repo/client" --script res://tests/task088_starter_quest_game_e2e.gd -- --test-live-ui --phase="$phase" > "$tmp/$phase.log" 2>&1 || { tail -50 "$tmp/$phase.log"; exit 1; }
  grep -q "TASK088 ${phase^^} PASS" "$tmp/$phase.log" || { tail -50 "$tmp/$phase.log"; exit 1; }
  echo "QUEST_PHASE $phase PASS"
done
echo 'TASK088 JSON STARTER QUEST E2E PASS'
