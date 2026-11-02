#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
LOG_DIR="$ROOT/tests/logs"
mkdir -p "$LOG_DIR"
"$GODOT_BIN" --headless --path "$ROOT/client" --editor --quit > "$LOG_DIR/avatar-import.log" 2>&1
timeout 46 "$GODOT_BIN" --headless --path "$ROOT/client" -- --dedicated-server > "$LOG_DIR/avatar-server.log" 2>&1 &
server=$!
trap 'kill "$server" 2>/dev/null || true' EXIT
sleep 0.8
timeout 40 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/avatar_jump_e2e.gd -- --a > "$LOG_DIR/avatar-a.log" 2>&1 &
a=$!
trap 'kill "$a" "$server" 2>/dev/null || true' EXIT
sleep 0.4
timeout 40 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/avatar_jump_e2e.gd -- --b > "$LOG_DIR/avatar-b.log" 2>&1
wait "$a"
kill "$server" 2>/dev/null || true
wait "$server" 2>/dev/null || true
trap - EXIT
if grep -Ei 'SCRIPT ERROR|Parse Error|AVATAR/JUMP FAIL' "$LOG_DIR"/avatar-{import,server,a,b}.log; then
  echo 'FAIL: avatar selection or jump E2E error'
  exit 1
fi
grep -q 'AVATAR SYNC PASS A' "$LOG_DIR/avatar-a.log"
grep -q 'AVATAR SYNC PASS B' "$LOG_DIR/avatar-b.log"
grep -q 'JUMP REMOTE PASS A' "$LOG_DIR/avatar-a.log"
grep -q 'JUMP LOCAL PASS B' "$LOG_DIR/avatar-b.log"
echo 'PASS: two independent Godot clients choose different heroes and replicate airborne jump/landing.'
