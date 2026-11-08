#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
tmp="$(mktemp -d)"
server=""; a=""; b=""
cleanup() {
  for pid in "$server" "$a" "$b"; do
    [[ -z "$pid" ]] || kill "$pid" 2>/dev/null || true
  done
  rm -rf "$tmp"
}
trap cleanup EXIT
ELDORIA_SAVE_PATH="$tmp/world.json" timeout 45 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task087_tree_regrowth_network_e2e.gd -- --dedicated-server --websocket --role-server > "$tmp/server.log" 2>&1 & server=$!
sleep 1.5
timeout 40 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task087_tree_regrowth_network_e2e.gd -- --test-live-ui --role-a > "$tmp/a.log" 2>&1 & a=$!
sleep 0.3
timeout 40 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task087_tree_regrowth_network_e2e.gd -- --test-live-ui --role-b > "$tmp/b.log" 2>&1 & b=$!
for pid in "$server" "$a" "$b"; do
  if ! wait "$pid"; then
    for role in server a b; do tail -20 "$tmp/$role.log"; done
    exit 1
  fi
done
server="";a="";b=""
grep -q 'TASK087 NETWORK SERVER PASS' "$tmp/server.log"
for role in a b; do grep -q 'TASK087 NETWORK CLIENT PASS' "$tmp/$role.log"; done
if grep -E 'SCRIPT ERROR|Parse Error|TASK087 NETWORK FAIL' "$tmp/"{server,a,b}.log; then exit 1; fi
echo 'TASK087 NETWORK PASS two WS clients saw 0 -> full tree restored'
