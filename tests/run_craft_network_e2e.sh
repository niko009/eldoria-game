#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
LOG_DIR="$ROOT/tests/logs"
mkdir -p "$LOG_DIR"
host=""
a=""
b=""
cleanup() {
  for pid in "$host" "$a" "$b"; do
    if [ -n "$pid" ]; then kill "$pid" 2>/dev/null || true; fi
  done
}
trap cleanup EXIT
# Isolated local WebSocket dedicated host; NO public services or production DB.
timeout 55 "$GODOT_BIN" --headless --path "$ROOT/client" \
  --script res://tests/craft_network_host_e2e.gd -- --dedicated-server --websocket \
  >"$LOG_DIR/craft-network-server.log" 2>&1 &
host=$!
sleep 0.8
timeout 48 "$GODOT_BIN" --headless --path "$ROOT/client" \
  --script res://tests/craft_network_client_e2e.gd -- --a --test-live-ui \
  >"$LOG_DIR/craft-network-a.log" 2>&1 &
a=$!
sleep 0.25
timeout 48 "$GODOT_BIN" --headless --path "$ROOT/client" \
  --script res://tests/craft_network_client_e2e.gd -- --b --test-live-ui \
  >"$LOG_DIR/craft-network-b.log" 2>&1 &
b=$!
wait "$a"; a=""
wait "$b"; b=""
wait "$host"; host=""
grep -q 'CRAFT NETWORK SERVER PASS' "$LOG_DIR/craft-network-server.log"
grep -q 'CRAFT NETWORK CLIENT PASS A' "$LOG_DIR/craft-network-a.log"
grep -q 'CRAFT NETWORK CLIENT PASS B' "$LOG_DIR/craft-network-b.log"
if grep -E 'SCRIPT ERROR|Parse Error|CRAFT NETWORK .*FAIL' "$LOG_DIR"/craft-network-{server,a,b}.log; then
  echo 'Unexpected Godot network test error' >&2
  exit 1
fi
echo 'CRAFT NETWORK PASS: dedicated WebSocket + two real clients, unique axe, isolated inventories, duplicate and unfunded requests denied.'
