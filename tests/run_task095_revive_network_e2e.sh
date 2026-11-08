#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
godot="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
tmp="$(mktemp -d)"
server="" ; a="" ; b=""
cleanup(){ for pid in "$server" "$a" "$b"; do [[ -z "$pid" ]] || kill "$pid" 2>/dev/null || true; done; rm -rf "$tmp"; }
trap cleanup EXIT
ELDORIA_SAVE_PATH="$tmp/world.json" timeout 35 "$godot" --headless --path "$root/client" --script res://tests/task095_revive_network_e2e.gd -- --dedicated-server --websocket --role-server >"$tmp/server.log" 2>&1 & server=$!
sleep 0.8
timeout 35 "$godot" --headless --path "$root/client" --script res://tests/task095_revive_network_e2e.gd -- --test-live-ui --role-rescuer >"$tmp/a.log" 2>&1 & a=$!
sleep 0.2
timeout 35 "$godot" --headless --path "$root/client" --script res://tests/task095_revive_network_e2e.gd -- --test-live-ui --role-victim >"$tmp/b.log" 2>&1 & b=$!
for pid in "$server" "$a" "$b"; do if ! wait "$pid"; then for role in server a b; do tail -24 "$tmp/$role.log"; done; exit 1; fi; done
server="";a="";b=""
grep -q 'TASK095 WSS SERVER PASS' "$tmp/server.log"
grep -q 'TASK095 WSS RESCUER PASS' "$tmp/a.log"
grep -q 'TASK095 WSS VICTIM PASS' "$tmp/b.log"
if grep -E 'SCRIPT ERROR|Parse Error|TASK095 WSS FAIL' "$tmp"/{server,a,b}.log;then exit 1;fi
echo 'TASK095 TWO-CLIENT WSS PASS'
