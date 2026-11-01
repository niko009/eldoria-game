#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
LOG_DIR="${LOG_DIR:-$ROOT/tests/logs}"
mkdir -p "$LOG_DIR"
"$GODOT_BIN" --headless --path "$ROOT/client" --editor --quit > "$LOG_DIR/dedicated-import.log" 2>&1
timeout 38 "$GODOT_BIN" --headless --path "$ROOT/client" -- --dedicated-server > "$LOG_DIR/dedicated-server.log" 2>&1 &
server=$!
timeout 30 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/dedicated_e2e.gd -- --a > "$LOG_DIR/dedicated-a.log" 2>&1 &
client_a=$!
trap 'kill "$client_a" "$server" 2>/dev/null || true' EXIT
sleep 1
timeout 30 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/dedicated_e2e.gd -- --b > "$LOG_DIR/dedicated-b.log" 2>&1
wait "$client_a"
kill "$server" 2>/dev/null || true
wait "$server" 2>/dev/null || true
trap - EXIT
if grep -Ei '(^|[^A-Z])(ERROR|SCRIPT ERROR|Parse Error|CROSS-PLATFORM FAIL):' "$LOG_DIR"/dedicated-{import,server,a,b}.log; then
    echo "FAIL: Godot reported errors" >&2
    exit 1
fi
grep -q 'DEDICATED SERVER READY' "$LOG_DIR/dedicated-server.log"
for who in a b; do
    grep -q 'PROTOCOL MOVEMENT PASS' "$LOG_DIR/dedicated-$who.log"
    grep -q 'PROTOCOL INTERACTION PASS' "$LOG_DIR/dedicated-$who.log"
    grep -q 'PROTOCOL REJOIN' "$LOG_DIR/dedicated-$who.log"
done
echo "PASS: independent headless dedicated server + two clients + movement + interaction + disconnect + same-process reconnect."
