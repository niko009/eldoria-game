#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
LOG="$ROOT/tests/logs"
mkdir -p "$LOG"
server=""; veteran=""; beginner=""
cleanup() { for pid in "$server" "$veteran" "$beginner"; do [[ -z "$pid" ]] || kill "$pid" 2>/dev/null || true; done; }
trap cleanup EXIT
timeout 60 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task050_skills_network_server_e2e.gd -- --dedicated-server --websocket > "$LOG/task050-server.log" 2>&1 & server=$!
sleep 1
timeout 55 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task050_skills_network_client_e2e.gd -- --veteran --test-live-ui > "$LOG/task050-veteran.log" 2>&1 & veteran=$!
sleep 0.2
timeout 55 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task050_skills_network_client_e2e.gd -- --beginner --test-live-ui > "$LOG/task050-beginner.log" 2>&1 & beginner=$!
wait "$veteran"; veteran=""
wait "$beginner"; beginner=""
wait "$server"; server=""
grep -q 'TASK050 SKILL NETWORK SERVER PASS' "$LOG/task050-server.log"
grep -q 'TASK050 SKILL NETWORK CLIENT PASS VETERAN' "$LOG/task050-veteran.log"
grep -q 'TASK050 SKILL NETWORK CLIENT PASS BEGINNER' "$LOG/task050-beginner.log"
if grep -E 'SCRIPT ERROR|Parse Error|TASK050 .*FAIL' "$LOG"/task050-{server,veteran,beginner}.log; then exit 1; fi
echo 'TASK050 SKILLS NETWORK PASS: dedicated WS + 2 real clients with different damage and XP'
