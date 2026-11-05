#!/usr/bin/env bash
# TASK-080: isolated multiplayer gate: separate clients, combat, crafting, inventory isolation and reconnection.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
for suite in run_combat_e2e.sh run_craft_network_e2e.sh run_websocket_e2e.sh; do
  echo "[TASK-080] Running $suite"
  bash "tests/$suite"
  echo "[TASK-080] PASS $suite"
done
echo 'TASK080 COOP VALIDATION PASS combat, crafting, inventory isolation, reconnect'