#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
API_URL="http://127.0.0.1:19091"
LOG_DIR="$ROOT/tests/logs"
mkdir -p "$LOG_DIR"
: "${ELDORIA_TEST_PG_CONN:?Provide an ISOLATED PostgreSQL test connection}"
: "${ELDORIA_TEST_INTERNAL_KEY:?Provide a test API key, at least 24 characters}"
# Explicit destructive test DB constraint. Never run reset on production.
if [[ "$ELDORIA_TEST_PG_CONN" != *"Host=eldoria-task013-pg"* || "$ELDORIA_TEST_PG_CONN" != *"Database=eldoria_dev"* ]]; then
    echo 'Refusing test: expected disposable isolated eldoria-task013-pg/eldoria_dev.'
    exit 2
fi
api_pid=""
server=""
cleanup() {
    if [ -n "$server" ]; then kill "$server" 2>/dev/null || true; wait "$server" 2>/dev/null || true; fi
    if [ -n "$api_pid" ]; then kill "$api_pid" 2>/dev/null || true; wait "$api_pid" 2>/dev/null || true; fi
}
trap cleanup EXIT
cd "$ROOT"
dotnet build server/Eldoria.Persistence/Eldoria.Persistence.csproj -c Release -v:q >/dev/null
ELDORIA_POSTGRES_CONNECTION="$ELDORIA_TEST_PG_CONN" ELDORIA_INTERNAL_KEY="$ELDORIA_TEST_INTERNAL_KEY" \
    ELDORIA_DB_AUTO_MIGRATE=1 ASPNETCORE_URLS="$API_URL" \
    dotnet server/Eldoria.Persistence/bin/Release/net10.0/Eldoria.Persistence.dll \
      > "$LOG_DIR/postgres-api.log" 2>&1 &
api_pid=$!
for i in $(seq 1 35); do
    if curl -fsS -m 1 -H "X-Eldoria-Server-Key: $ELDORIA_TEST_INTERNAL_KEY" "$API_URL/health" >/dev/null; then break; fi
    sleep 0.2
done
curl -fsS -m 3 -H "X-Eldoria-Server-Key: $ELDORIA_TEST_INTERNAL_KEY" "$API_URL/health" >/dev/null
ELDORIA_TEST_INTERNAL_KEY="$ELDORIA_TEST_INTERNAL_KEY" node <<'JS'
const assert=require('node:assert/strict');
const base='http://127.0.0.1:19091';
const key=process.env.ELDORIA_TEST_INTERNAL_KEY;
(async()=>{
let r=await fetch(base+'/v1/world/20261101');
assert.equal(r.status,401,'API must require internal server secret');
let headers={'X-Eldoria-Server-Key':key,'Content-Type':'application/json'};
r=await fetch(base+'/v1/world/20261101',{headers}); assert.equal(r.status,200);
const current=await r.json();
assert.equal(current.schema,1);
const reset={schema:1,world_seed:20261101,revision:current.revision,depleted:{},profiles:{}};
r=await fetch(base+'/v1/world/20261101',{method:'PUT',headers,body:JSON.stringify(reset)});
assert.equal(r.status,200,'safe reset in explicitly disposable test database only');
r=await fetch(base+'/v1/world/20261101',{method:'PUT',headers,body:JSON.stringify(reset)});
assert.equal(r.status,409,'stale revision must conflict');
let malformed={...reset,revision:current.revision+1,profiles:{evil:{avatar:0,inventory:{wood:0,stone:0,herb:0}}}};
r=await fetch(base+'/v1/world/20261101',{method:'PUT',headers,body:JSON.stringify(malformed)});
assert.equal(r.status,400,'invalid hash must be rejected');
console.log('POSTGRES API PASS: auth 401, schema, atomic PUT, stale revision 409, invalid input 400');
})().catch(e=>{console.error(e);process.exitCode=1});
JS
IDENTITY="$(printf 'a%.0s' {1..64})"
"$GODOT_BIN" --headless --path "$ROOT/client" --editor --quit >"$LOG_DIR/postgres-import.log" 2>&1
for step in initial restored; do
    ELDORIA_PG_API_URL="$API_URL" ELDORIA_PG_API_KEY="$ELDORIA_TEST_INTERNAL_KEY" timeout 50 \
      "$GODOT_BIN" --headless --path "$ROOT/client" -- --dedicated-server \
      >"$LOG_DIR/postgres-server-$step.log" 2>&1 &
    server=$!
    sleep 1
    ELDORIA_TEST_IDENTITY="$IDENTITY" timeout 35 "$GODOT_BIN" --headless --path "$ROOT/client" \
      --script res://tests/persistence_e2e.gd -- --"$step" >"$LOG_DIR/postgres-client-$step.log" 2>&1
    grep -q "PERSIST ${step^^} PASS" "$LOG_DIR/postgres-client-$step.log"
    kill "$server" 2>/dev/null || true
    wait "$server" 2>/dev/null || true
    server=""
    sleep 0.4
done
ELDORIA_TEST_INTERNAL_KEY="$ELDORIA_TEST_INTERNAL_KEY" node <<'JS'
const assert=require('node:assert/strict');const crypto=require('node:crypto');
(async()=>{
 const h={'X-Eldoria-Server-Key':process.env.ELDORIA_TEST_INTERNAL_KEY};
 const r=await fetch('http://127.0.0.1:19091/v1/world/20261101',{headers:h});
 assert.equal(r.status,200);
 const data=await r.json();
 const hash=crypto.createHash('sha256').update('a'.repeat(64)).digest('hex');
 assert.equal(Object.keys(data.profiles).length,1);
 assert.equal(data.profiles[hash].avatar,2);
 assert.equal(data.profiles[hash].inventory.herb,1);
 assert.equal(Object.values(data.depleted).filter(v=>v===0).length,1);
 assert.equal(data.revision>=2,true);
 assert.equal(JSON.stringify(data).includes('a'.repeat(64)),false,'never persist raw bearer token');
 console.log('POSTGRES DATA PASS: hashed player, Mage, private herb inventory, shared depletion, revision='+data.revision);
})().catch(e=>{console.error(e);process.exitCode=1});
JS
# Exercise PostgreSQL-backed campfire/tent durability in two independent host processes.
for step in initial restored; do
    ELDORIA_PG_API_URL="$API_URL" ELDORIA_PG_API_KEY="$ELDORIA_TEST_INTERNAL_KEY" timeout 30 \
      "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/postgres_building_e2e.gd -- --"$step" \
      >"$LOG_DIR/postgres-build-$step.log" 2>&1
    grep -q "POSTGRES BUILD ${step^^} PASS" "$LOG_DIR/postgres-build-$step.log"
    grep "POSTGRES BUILD ${step^^} PASS" "$LOG_DIR/postgres-build-$step.log"
done
# A felled tree and harvested grass must remain removed after restarting the
# Godot host and reloading the same isolated PostgreSQL world.
for step in initial restored; do
    ELDORIA_PG_API_URL="$API_URL" ELDORIA_PG_API_KEY="$ELDORIA_TEST_INTERNAL_KEY" timeout 30 \
      "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/forest_depletion_persistence_e2e.gd -- --"$step" \
      >"$LOG_DIR/postgres-forest-$step.log" 2>&1
    grep -q "DEPLETION ${step^^} PASS" "$LOG_DIR/postgres-forest-$step.log"
    grep "DEPLETION ${step^^} PASS" "$LOG_DIR/postgres-forest-$step.log"
done
set +e
ELDORIA_PG_API_URL="$API_URL" ELDORIA_PG_API_KEY="WRONG_TEST_SECRET_DO_NOT_ACCEPT_2026" \
 timeout 14 "$GODOT_BIN" --headless --path "$ROOT/client" -- --dedicated-server \
 >"$LOG_DIR/postgres-denied-server.log" 2>&1
code=$?
set -e
if [ "$code" -eq 0 ] || [ "$code" -eq 124 ]; then echo 'FAIL: Godot server started with wrong DB API secret'; exit 1; fi
grep -q "refusing to host" "$LOG_DIR/postgres-denied-server.log"
for step in initial restored; do grep 'PERSIST .* PASS' "$LOG_DIR/postgres-client-$step.log"; done
echo 'POSTGRES INTEGRATION PASS: two actual Godot server processes, .NET/Npgsql, PostgreSQL restart recovery, authentication fail-closed.'
