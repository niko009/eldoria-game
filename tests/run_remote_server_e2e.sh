#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
LOG_DIR="${LOG_DIR:-$ROOT/tests/logs}"
: "${ELDORIA_SERVER_IP:?Set ELDORIA_SERVER_IP to the LAN IPv4 of the already-running host}"
mkdir -p "$LOG_DIR"
timeout 33 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/dedicated_e2e.gd -- --a > "$LOG_DIR/lan-a.log" 2>&1 &
client_a=$!
trap 'kill "$client_a" 2>/dev/null || true' EXIT
sleep 1
timeout 33 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/dedicated_e2e.gd -- --b > "$LOG_DIR/lan-b.log" 2>&1
wait "$client_a"
trap - EXIT
if grep -Ei '(^|[^A-Z])(ERROR|SCRIPT ERROR|Parse Error|CROSS-PLATFORM FAIL):' "$LOG_DIR"/lan-{a,b}.log; then
  echo "FAIL: LAN Godot errors" >&2
  exit 1
fi
for who in a b; do
  grep -q 'PROTOCOL MOVEMENT PASS' "$LOG_DIR/lan-$who.log"
  grep -q 'PROTOCOL INTERACTION PASS' "$LOG_DIR/lan-$who.log"
  grep -q 'PROTOCOL REJOIN' "$LOG_DIR/lan-$who.log"
done
echo "PASS: two independent Godot client processes against $ELDORIA_SERVER_IP:7777 dedicated host."
