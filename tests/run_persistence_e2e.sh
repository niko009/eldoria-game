#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
LOG_DIR="$ROOT/tests/logs"
mkdir -p "$LOG_DIR"
TMP="$(mktemp -d)"
SAVE_PATH="$TMP/world.json"
IDENTITY="$(printf 'a%.0s' {1..64})"
server=""
cleanup() { if [ -n "$server" ]; then kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; fi; rm -rf "$TMP"; }
trap cleanup EXIT
"$GODOT_BIN" --headless --path "$ROOT/client" --editor --quit > "$LOG_DIR/persistence-import.log" 2>&1
for step in initial restored; do
    ELDORIA_SAVE_PATH="$SAVE_PATH" timeout 45 "$GODOT_BIN" --headless --path "$ROOT/client" -- --dedicated-server > "$LOG_DIR/persistence-server-$step.log" 2>&1 &
    server=$!
    sleep 1
    ELDORIA_TEST_IDENTITY="$IDENTITY" timeout 35 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/persistence_e2e.gd -- --"$step" > "$LOG_DIR/persistence-client-$step.log" 2>&1
    grep -q "PERSIST ${step^^} PASS" "$LOG_DIR/persistence-client-$step.log"
    kill "$server" 2>/dev/null || true
    wait "$server" 2>/dev/null || true
    server=""
    test -s "$SAVE_PATH"
    if grep -q "$IDENTITY" "$SAVE_PATH"; then
        echo 'FAIL: plaintext bearer identity persisted'
        exit 1
    fi
    node - "$SAVE_PATH" <<'JS'
const fs=require('fs');
const j=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));
if(j.schema!==1||j.world_seed!==20261101||Object.keys(j.profiles).length!==1||
   Object.keys(j.depleted).length<1||Object.values(j.profiles)[0].inventory.herb!==1)
    process.exit(1);
console.log('SAVE JSON VALIDATED',Object.keys(j.profiles).length,Object.keys(j.depleted).length);
JS
    sleep 0.6
done
for stage in initial restored; do
    grep 'PERSIST .* PASS' "$LOG_DIR/persistence-client-$stage.log"
done
if grep -Ei 'SCRIPT ERROR|Parse Error|PERSISTENCE SAVE ERROR|PERSIST E2E FAIL' "$LOG_DIR"/persistence-{import,server-*,client-*}.log; then exit 1; fi
# A corrupted world save must fail CLOSED; never silently reset the economy.
printf 'this is not JSON' > "$SAVE_PATH"
set +e
ELDORIA_SAVE_PATH="$SAVE_PATH" timeout 12 "$GODOT_BIN" --headless --path "$ROOT/client" -- --dedicated-server >"$LOG_DIR/persistence-corrupt-server.log" 2>&1
corrupt_code=$?
set -e
if [ "$corrupt_code" -eq 0 ] || [ "$corrupt_code" -eq 124 ]; then
    echo "FAIL: corrupt world save did not stop server (code=$corrupt_code)"
    exit 1
fi
grep -q "Cannot load Eldoria save" "$LOG_DIR/persistence-corrupt-server.log"
echo 'PASS: corrupt snapshot refuses to start the server (no silent reset)'
echo 'PASS: persistent anonymous identity, private inventory and depleted resource survive real Godot server restart.'
