#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
LOG="$ROOT/tests/logs"
mkdir -p "$LOG"
server=""; attacker=""; witness=""
cleanup() { for pid in "$server" "$attacker" "$witness"; do [[ -z "$pid" ]] || kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT
timeout 50 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task047_bow_network_server_e2e.gd -- --dedicated-server --websocket > "$LOG/task047-server.log" 2>&1 & server=$!
sleep 1
timeout 45 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task047_bow_network_client_e2e.gd -- --attacker --test-live-ui > "$LOG/task047-attacker.log" 2>&1 & attacker=$!
sleep 0.2
timeout 45 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task047_bow_network_client_e2e.gd -- --witness --test-live-ui > "$LOG/task047-witness.log" 2>&1 & witness=$!
wait "$attacker"; attacker=""
wait "$witness"; witness=""
wait "$server"; server=""
grep -q 'TASK047 BOW NETWORK SERVER PASS' "$LOG/task047-server.log"
grep -q 'TASK047 BOW NETWORK CLIENT PASS ATTACKER' "$LOG/task047-attacker.log"
grep -q 'TASK047 BOW NETWORK CLIENT PASS WITNESS' "$LOG/task047-witness.log"
if grep -E 'SCRIPT ERROR|Parse Error|TASK047 .*FAIL' "$LOG"/task047-{server,attacker,witness}.log; then exit 1; fi
echo 'TASK047 BOW NETWORK PASS: dedicated WS + 2 actual clients, miss + aimed hit'
