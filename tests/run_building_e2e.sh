#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
LOG="$ROOT/tests/logs"
mkdir -p "$LOG"
"$GODOT_BIN" --headless --path "$ROOT/client" --editor --quit > "$LOG/building-import.log" 2>&1
"$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/building_logic_e2e.gd -- --test > "$LOG/building-logic.log" 2>&1
grep -q 'BUILD LOGIC PASS' "$LOG/building-logic.log"

timeout 50 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/building_server_e2e.gd -- --dedicated-server --websocket > "$LOG/building-server.log" 2>&1 &
server=$!
trap 'kill "$server" 2>/dev/null || true' EXIT
sleep 1
timeout 40 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/building_network_e2e.gd -- --a >"$LOG/building-a.log" 2>&1 &
a=$!
trap 'kill "$server" "$a" 2>/dev/null || true' EXIT
sleep 0.5
timeout 40 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/building_network_e2e.gd -- --b >"$LOG/building-b.log" 2>&1
wait "$a"
wait "$server"
trap - EXIT
for marker in 'BUILD NETWORK SERVER PASS' 'BUILD NETWORK CLIENT PASS A' 'BUILD NETWORK CLIENT PASS B'; do
    if ! grep -q "$marker" "$LOG"/building-{server,a,b}.log; then
        echo "MISSING: $marker"
        exit 1
    fi
done
if grep -E 'SCRIPT ERROR|Parse Error|BUILD .*FAIL' "$LOG"/building-{import,logic,server,a,b}.log; then
    exit 1
fi
echo 'BUILD NETWORK PASS: both Godot WebSocket clients see server-authoritative campfire/tent and independent inventory.'
