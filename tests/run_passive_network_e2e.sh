#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
LOG="$ROOT/tests/logs"
mkdir -p "$LOG"
server=""; hunter=""; observer=""
cleanup() { for pid in "$server" "$hunter" "$observer"; do [[ -z "$pid" ]] || kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT
timeout 60 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task048_passive_network_server_e2e.gd -- --dedicated-server --websocket > "$LOG/task048-server.log" 2>&1 & server=$!
sleep 1
timeout 55 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task048_passive_network_client_e2e.gd -- --hunter --test-live-ui > "$LOG/task048-hunter.log" 2>&1 & hunter=$!
sleep 0.2
timeout 55 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task048_passive_network_client_e2e.gd -- --observer --test-live-ui > "$LOG/task048-observer.log" 2>&1 & observer=$!
wait "$hunter"; hunter=""
wait "$observer"; observer=""
wait "$server"; server=""
grep -q 'TASK048 PASSIVE NETWORK SERVER PASS' "$LOG/task048-server.log"
grep -q 'TASK048 PASSIVE NETWORK CLIENT PASS HUNTER' "$LOG/task048-hunter.log"
grep -q 'TASK048 PASSIVE NETWORK CLIENT PASS OBSERVER' "$LOG/task048-observer.log"
if grep -E 'SCRIPT ERROR|Parse Error|TASK048 .*FAIL' "$LOG"/task048-{server,hunter,observer}.log; then exit 1; fi
echo 'TASK048 PASSIVE NETWORK PASS: two real clients see passive mobs and personal practice points'
