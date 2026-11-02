#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
LOG_DIR="${LOG_DIR:-$ROOT/tests/logs}"
mkdir -p "$LOG_DIR"

"$GODOT_BIN" --headless --path "$ROOT/client" --editor --quit >"$LOG_DIR/import.log" 2>&1
timeout 25 "$GODOT_BIN" --headless --path "$ROOT/client" \
    --script res://tests/network_e2e.gd -- --host >"$LOG_DIR/host.log" 2>&1 &
host_pid=$!
trap 'kill "$host_pid" 2>/dev/null || true' EXIT
sleep 0.75

timeout 22 "$GODOT_BIN" --headless --path "$ROOT/client" \
    --script res://tests/network_e2e.gd -- --client >"$LOG_DIR/client.log" 2>&1
wait "$host_pid"
trap - EXIT

if grep -Ei '(^|[^A-Z])(ERROR|SCRIPT ERROR|Parse Error|E2E FAIL):' \
        "$LOG_DIR/import.log" "$LOG_DIR/host.log" "$LOG_DIR/client.log"; then
    echo "FAIL: Godot logged an error" >&2
    exit 1
fi

grep -q 'E2E MOVEMENT PASS role=host' "$LOG_DIR/host.log"
grep -q 'E2E MOVEMENT PASS role=client' "$LOG_DIR/client.log"
grep -q 'E2E DISCONNECT PASS' "$LOG_DIR/host.log"
grep -q 'E2E RECONNECT PASS' "$LOG_DIR/host.log"
grep -q 'E2E CLIENT REJOIN PASS' "$LOG_DIR/client.log"

echo 'PASS: Godot import + two independent ENet processes + both move + disconnect + same client process reconnects and moves.'
echo "Logs: $LOG_DIR"