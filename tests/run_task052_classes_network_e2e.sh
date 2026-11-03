#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
LOG="$ROOT/tests/logs"
mkdir -p "$LOG"
server=""; mage=""; rogue=""
cleanup() { for pid in "$server" "$mage" "$rogue"; do [[ -z "$pid" ]] || kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT
timeout 55 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task052_classes_network_server_e2e.gd -- --dedicated-server --websocket > "$LOG/task052-server.log" 2>&1 & server=$!
sleep 1
timeout 50 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task052_classes_network_client_e2e.gd -- --mage --test-live-ui > "$LOG/task052-mage.log" 2>&1 & mage=$!
sleep 0.25
timeout 50 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task052_classes_network_client_e2e.gd -- --rogue --test-live-ui > "$LOG/task052-rogue.log" 2>&1 & rogue=$!
wait "$mage"; mage=""
wait "$rogue"; rogue=""
wait "$server"; server=""
grep -q 'TASK052 HERO NETWORK SERVER PASS' "$LOG/task052-server.log"
grep -q 'TASK052 HERO NETWORK CLIENT PASS MAGE' "$LOG/task052-mage.log"
grep -q 'TASK052 HERO NETWORK CLIENT PASS ROGUE' "$LOG/task052-rogue.log"
if grep -E 'SCRIPT ERROR|Parse Error|TASK052 .*FAIL' "$LOG"/task052-{server,mage,rogue}.log; then exit 1; fi
echo 'TASK052 HERO NETWORK PASS dedicated WS, Mage heal + Rogue dash with independent client UI'
