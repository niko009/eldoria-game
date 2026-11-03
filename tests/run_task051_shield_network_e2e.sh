#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
LOG="$ROOT/tests/logs"
mkdir -p "$LOG"
server=""; defender=""; archer=""
cleanup() { for pid in "$server" "$defender" "$archer"; do [[ -z "$pid" ]] || kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT
timeout 55 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task051_shield_network_server_e2e.gd -- --dedicated-server --websocket > "$LOG/task051-server.log" 2>&1 & server=$!
sleep 1
timeout 50 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task051_shield_network_client_e2e.gd -- --defender --test-live-ui > "$LOG/task051-defender.log" 2>&1 & defender=$!
sleep 0.2
timeout 50 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task051_shield_network_client_e2e.gd -- --archer --test-live-ui > "$LOG/task051-archer.log" 2>&1 & archer=$!
wait "$defender"; defender=""
wait "$archer"; archer=""
wait "$server"; server=""
grep -q 'TASK051 SHIELD NETWORK SERVER PASS' "$LOG/task051-server.log"
grep -q 'TASK051 SHIELD NETWORK CLIENT PASS DEFENDER' "$LOG/task051-defender.log"
grep -q 'TASK051 SHIELD NETWORK CLIENT PASS ARCHER' "$LOG/task051-archer.log"
if grep -E 'SCRIPT ERROR|Parse Error|TASK051 .*FAIL' "$LOG"/task051-{server,defender,archer}.log; then exit 1; fi
echo 'TASK051 SHIELD NETWORK PASS: 2 clients, shield taunt, cooldown, isolated equipment'
