#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
LOG="$ROOT/tests/logs"
mkdir -p "$LOG"
pids=()
cleanup() { for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT
for role in server a b; do
  args=("--$role")
  [[ "$role" != server ]] || args=(--dedicated-server --websocket)
  timeout 25 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task086_network_e2e.gd -- "${args[@]}" >"$LOG/task086-network-$role.log" 2>&1 &
  pids+=("$!")
  sleep 0.3
done
for pid in "${pids[@]}"; do wait "$pid"; done
pids=()
grep -q 'TASK086 NETWORK SERVER PASS' "$LOG/task086-network-server.log"
for role in a b; do grep -q 'TASK086 NETWORK CLIENT PASS' "$LOG/task086-network-$role.log"; done
if grep -E 'ERROR|FAIL' "$LOG"/task086-network-{server,a,b}.log; then exit 1; fi
echo 'TASK086 NETWORK PASS: two real clients match bow draw, action sequence, wolf hit and death'
