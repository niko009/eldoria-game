#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
cd "$ROOT"
for entry in \
  'task072_equipment_validation_e2e|TASK072 EQUIPMENT VALIDATION PASS' \
  'task073_staff_ui_e2e|TASK073 STAFF UI PASS' \
  'task075_mana_potion_ui_e2e|TASK075 MANA POTION UI PASS' \
  'task075_mana_herb_world_e2e|TASK075 MANA HERB WORLD PASS' \
  'task076_pack_bite_balance_e2e|TASK076 PACK BITE BALANCE PASS' \
  'task076_wolf_windup_e2e|TASK076 WOLF WINDUP PASS'; do
  name="${entry%%|*}"
  marker="${entry#*|}"
  result="$("$GODOT_BIN" --headless --path "$ROOT/client" --script "res://tests/$name.gd" 2>&1)" || { echo "$result"; exit 1; }
  if ! grep -q "$marker" <<<"$result"; then
    echo "FAIL $name (success marker missing)" >&2
    echo "$result" >&2
    exit 1
  fi
  echo "PASS $name"
done
result="$("$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task078_consumable_server_e2e.gd -- --test-live-ui 2>&1)" || { echo "$result"; exit 1; }
grep -q 'TASK078 SERVER ACTIONS PASS' <<<"$result" || { echo "$result"; exit 1; }
echo 'PASS task078_consumable_server_e2e'