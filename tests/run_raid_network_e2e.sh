#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
LOG="$ROOT/tests/logs"
mkdir -p "$LOG"
server=""; a=""; b=""
cleanup() {
  for pid in "$server" "$a" "$b"; do
    if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; fi
  done
}
trap cleanup EXIT
timeout 65 "$GODOT_BIN" --headless --path "$ROOT/client" \
  --script res://tests/task039_raid_network_server_e2e.gd -- --dedicated-server --websocket \
  > "$LOG/task039-raid-server.log" 2>&1 &
server=$!
sleep 1
timeout 60 "$GODOT_BIN" --headless --path "$ROOT/client" \
  --script res://tests/task039_raid_network_client_e2e.gd -- --attacker --test-live-ui \
  > "$LOG/task039-raid-attacker.log" 2>&1 &
a=$!
sleep 0.2
timeout 60 "$GODOT_BIN" --headless --path "$ROOT/client" \
  --script res://tests/task039_raid_network_client_e2e.gd -- --medic --test-live-ui \
  > "$LOG/task039-raid-medic.log" 2>&1 &
b=$!
wait "$a"; a=""
wait "$b"; b=""
wait "$server"; server=""
grep -q 'TASK039 RAID NETWORK SERVER PASS' "$LOG/task039-raid-server.log"
grep -q 'TASK039 RAID NETWORK CLIENT PASS ATTACKER' "$LOG/task039-raid-attacker.log"
grep -q 'TASK039 RAID NETWORK CLIENT PASS MEDIC' "$LOG/task039-raid-medic.log"
if grep -E 'SCRIPT ERROR|Parse Error|TASK039 RAID NETWORK .*FAIL' "$LOG"/task039-raid-{server,attacker,medic}.log; then exit 1; fi
echo 'TASK039 RAID NETWORK PASS: dedicated WS + 2 actual clients'
