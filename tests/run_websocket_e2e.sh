#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
LOG="$ROOT/tests/logs"
mkdir -p "$LOG"
"$GODOT_BIN" --headless --path "$ROOT/client" --editor --quit > "$LOG/websocket-import.log" 2>&1
timeout 37 "$GODOT_BIN" --headless --path "$ROOT/client" -- --dedicated-server --websocket > "$LOG/websocket-server.log" 2>&1 &
server=$!
trap 'kill "$server" 2>/dev/null || true' EXIT
sleep 1
timeout 30 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/websocket_e2e.gd -- --a > "$LOG/websocket-a.log" 2>&1 &
a=$!
trap 'kill "$server" "$a" 2>/dev/null || true' EXIT
sleep 1
timeout 30 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/websocket_e2e.gd -- --b > "$LOG/websocket-b.log" 2>&1
wait "$a"
kill "$server" 2>/dev/null || true
wait "$server" 2>/dev/null || true
trap - EXIT
grep -q 'SERVER READY WS' "$LOG/websocket-server.log"
for c in a b; do
  grep -q 'WEBSOCKET PROTOCOL MOVEMENT PASS' "$LOG/websocket-$c.log"
  grep -q 'WEBSOCKET PROTOCOL INTERACTION PASS' "$LOG/websocket-$c.log"
  grep -q 'WEBSOCKET PROTOCOL REJOIN' "$LOG/websocket-$c.log"
done
if grep -Ei '(ERROR|SCRIPT ERROR|Parse Error|WEBSOCKET FAIL):' "$LOG"/websocket-{server,a,b,import}.log; then exit 1; fi
echo 'PASS: WebSocket dedicated host with two actual independent Godot clients: motion, Wave, reconnect.'
