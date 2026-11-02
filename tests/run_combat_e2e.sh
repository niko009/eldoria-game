#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
LOG="$ROOT/tests/logs"
mkdir -p "$LOG"
server=""; a=""; b=""
cleanup(){ for pid in "$server" "$a" "$b"; do if [ -n "$pid" ]; then kill "$pid" 2>/dev/null || true; fi; done; }
trap cleanup EXIT
timeout 58 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/combat_network_server_e2e.gd -- --dedicated-server --websocket >"$LOG/combat-network-server.log" 2>&1 &
server=$!
sleep 1
timeout 52 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/combat_network_client_e2e.gd -- --a --test-live-ui >"$LOG/combat-network-a.log" 2>&1 &
a=$!
sleep 0.3
timeout 52 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/combat_network_client_e2e.gd -- --b --test-live-ui >"$LOG/combat-network-b.log" 2>&1 &
b=$!
wait "$a"; a=""
wait "$b"; b=""
wait "$server"; server=""
grep -q 'COMBAT NETWORK SERVER PASS' "$LOG/combat-network-server.log"
grep -q 'COMBAT NETWORK CLIENT PASS A' "$LOG/combat-network-a.log"
grep -q 'COMBAT NETWORK CLIENT PASS B' "$LOG/combat-network-b.log"
if grep -E 'SCRIPT ERROR|Parse Error|COMBAT NETWORK .*FAIL' "$LOG"/combat-network-*.log; then exit 1; fi
echo 'TASK-025 COMBAT NETWORK PASS (WebSocket dedicated + two clients)'
