#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
LOG_DIR="$ROOT/tests/logs"
mkdir -p "$LOG_DIR"
tmp="$(mktemp -d)"
server_pid=""
api_pid=""
cleanup() { [ -z "$server_pid" ] || kill "$server_pid" 2>/dev/null || true; [ -z "$api_pid" ] || kill "$api_pid" 2>/dev/null || true; rm -rf "$tmp"; }
trap cleanup EXIT
"$GODOT_BIN" --headless --path "$ROOT/client" --editor --quit >"$LOG_DIR/task018-import.log" 2>&1
"$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/telemetry_e2e.gd -- --test >"$LOG_DIR/task018-client.log" 2>&1
grep -q 'TELEMETRY CLIENT PASS' "$LOG_DIR/task018-client.log"
ELDORIA_MOCK_LOG="$tmp/telemetry.jsonl" node "$ROOT/tests/mock_telemetry_api.js" >"$LOG_DIR/task018-mock-api.log" 2>&1 &
api_pid=$!
sleep 0.5
ELDORIA_PG_API_URL=http://127.0.0.1:19091 ELDORIA_PG_API_KEY=task018-telemetry-test-local-only-key \
  timeout 38 "$GODOT_BIN" --headless --path "$ROOT/client" -- --dedicated-server >"$LOG_DIR/task018-dedicated.log" 2>&1 &
server_pid=$!
sleep 1.5
timeout 30 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/telemetry_network_e2e.gd -- --test >"$LOG_DIR/task018-network-client.log" 2>&1
grep -q 'TELEMETRY NETWORK CLIENT PASS' "$LOG_DIR/task018-network-client.log"
for attempt in $(seq 1 48); do
  [ -s "$tmp/telemetry.jsonl" ] && break
  sleep 0.25
done
if grep -E 'SCRIPT ERROR|Parse Error|ERR_UNCONFIGURED' "$LOG_DIR/task018-dedicated.log"; then exit 1; fi
node - "$tmp/telemetry.jsonl" <<'JS'
const fs=require('node:fs'),assert=require('node:assert/strict');
const samples=fs.readFileSync(process.argv[2],'utf8').trim().split('\n').filter(Boolean).map(x=>JSON.parse(x));
assert.equal(samples.length,1,'client duplicates must be server-rate-limited');
assert.equal(samples[0].fps_avg,47.1);
assert.equal(samples[0].platform,'test');
assert.ok(!JSON.stringify(samples).match(/token|identity|email|ip_address/i));
console.log('TELEMETRY FULL NETWORK PASS: client ENet -> Godot dedicated -> async HTTP, anti-spam and privacy');
JS
