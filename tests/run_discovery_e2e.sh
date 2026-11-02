#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
LOG_DIR="$ROOT/tests/logs"
mkdir -p "$LOG_DIR"
"$GODOT_BIN" --headless --path "$ROOT/client" --editor --quit > "$LOG_DIR/discovery-import.log" 2>&1
# Local deterministic HTTP config provider, identical JSON schema to bacus.dev.
node -e 'require("http").createServer((req,res)=>{res.writeHead(200,{"Content-Type":"application/json","Cache-Control":"no-store"});res.end(JSON.stringify({schema:1,protocol:"godot-enet",client_version:"0.2.1",status:"lan",host:"127.0.0.1",port:7777}))}).listen(18087,"127.0.0.1")' > "$LOG_DIR/discovery-http.log" 2>&1 &
web=$!
timeout 38 "$GODOT_BIN" --headless --path "$ROOT/client" -- --dedicated-server > "$LOG_DIR/discovery-server.log" 2>&1 &
server=$!
trap 'kill "$server" "$web" 2>/dev/null || true' EXIT
sleep 0.6
export ELDORIA_CONFIG_URL=http://127.0.0.1:18087/
timeout 33 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/discovery_e2e.gd -- --a > "$LOG_DIR/discovery-a.log" 2>&1 &
a=$!
trap 'kill "$server" "$web" "$a" 2>/dev/null || true' EXIT
sleep 0.4
timeout 33 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/discovery_e2e.gd -- --b > "$LOG_DIR/discovery-b.log" 2>&1
wait "$a"
kill "$server" "$web" 2>/dev/null || true
wait "$server" 2>/dev/null || true
wait "$web" 2>/dev/null || true
trap - EXIT
if grep -Ei '(^|[^A-Z])(ERROR|SCRIPT ERROR|Parse Error|DISCOVERY FAIL):' "$LOG_DIR"/discovery-{import,server,a,b}.log; then
    echo "FAIL: errors in discovery E2E" >&2
    exit 1
fi
for role in a b; do
    grep -q 'DISCOVERY CONNECT PASS' "$LOG_DIR/discovery-$role.log"
    grep -q 'DISCOVERY MOVEMENT PASS' "$LOG_DIR/discovery-$role.log"
    grep -q 'DISCOVERY WAVE PASS' "$LOG_DIR/discovery-$role.log"
done
grep -q 'DISCOVERY REDISCOVERY PASS B' "$LOG_DIR/discovery-b.log"
grep -q 'DISCOVERY RECONNECT PASS A' "$LOG_DIR/discovery-a.log"
echo "PASS: HTTP endpoint discovery + two ENet clients + movement + Wave + rediscovery/reconnect."
