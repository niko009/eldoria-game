#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
LOG_DIR="$ROOT/tests/logs"
mkdir -p "$LOG_DIR"
"$GODOT_BIN" --headless --path "$ROOT/client" --editor --quit >"$LOG_DIR/resources-import.log" 2>&1
timeout 38 "$GODOT_BIN" --headless --path "$ROOT/client" -- --dedicated-server >"$LOG_DIR/resources-server.log" 2>&1 &
server=$!
trap 'kill "$server" 2>/dev/null || true' EXIT
sleep 0.7
timeout 34 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/resource_e2e.gd -- --a >"$LOG_DIR/resources-a.log" 2>&1 &
a=$!
trap 'kill "$a" "$server" 2>/dev/null || true' EXIT
sleep 0.4
timeout 34 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/resource_e2e.gd -- --b >"$LOG_DIR/resources-b.log" 2>&1
wait "$a"
kill "$server" 2>/dev/null || true
wait "$server" 2>/dev/null || true
trap - EXIT
if grep -Ei '(^|[^A-Z])(ERROR|SCRIPT ERROR|Parse Error|RESOURCE E2E FAIL):' "$LOG_DIR"/resources-{import,server,a,b}.log; then
  exit 1
fi
for role in a b; do
  grep -q 'RESOURCE OWN INVENTORY PASS' "$LOG_DIR/resources-$role.log"
  grep -q 'RESOURCE AUTHORITATIVE SYNC PASS' "$LOG_DIR/resources-$role.log"
done
echo 'PASS: two clients gather independent herbs, share depletion, reject invalid requests.'
