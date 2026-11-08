#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
godot="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
tmp="$(mktemp -d)"
s="" ; a="" ; b=""
cleanup(){ for pid in "$s" "$a" "$b"; do [[ -z "$pid" ]] || kill "$pid" 2>/dev/null || true; done; rm -rf "$tmp"; }
trap cleanup EXIT
ELDORIA_SAVE_PATH="$tmp/world.json" timeout 38 "$godot" --headless --path "$root/client" --script res://tests/task088_starter_quest_wss_e2e.gd -- --dedicated-server --websocket --role-server >"$tmp/s.log" 2>&1 & s=$!
sleep 0.7
ELDORIA_TEST_IDENTITY="$(printf '%064d' 1)" timeout 38 "$godot" --headless --path "$root/client" --script res://tests/task088_starter_quest_wss_e2e.gd -- --test-live-ui --role-knight >"$tmp/a.log" 2>&1 & a=$!
sleep 0.25
ELDORIA_TEST_IDENTITY="$(printf '%064d' 2)" timeout 38 "$godot" --headless --path "$root/client" --script res://tests/task088_starter_quest_wss_e2e.gd -- --test-live-ui --role-mage >"$tmp/b.log" 2>&1 & b=$!
for pid in "$s" "$a" "$b"; do if ! wait "$pid";then for f in s a b; do tail -30 "$tmp/$f.log"; done;exit 1;fi;done
s="";a="";b=""
for x in 'SERVER:s' 'KNIGHT:a' 'MAGE:b';do role="${x%%:*}";f="${x##*:}"; grep -q "TASK088 WSS $role PASS" "$tmp/$f.log" || { tail -40 "$tmp/$f.log";exit 1;};done
if grep -E 'SCRIPT ERROR|Parse Error|TASK088 WSS FAIL' "$tmp"/{s,a,b}.log;then exit 1;fi
echo 'TASK088 TWO-CLIENT WSS QUEST PASS'
