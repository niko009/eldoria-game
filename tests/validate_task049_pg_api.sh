#!/usr/bin/env bash
# Staging-only integration test. Must never connect to eldoria-prod-postgres.
set -Eeuo pipefail
STAGE=${TASK049_STAGE:-/srv/bacus/apps/eldoria-releases/task049-api-validation}
CONTAINER=eldoria-task049-validation-pg
DB_PORT=19491
API_PORT=19492
[[ -f "$STAGE/004_skills_crafting.sql" && -x "$STAGE/Eldoria.Persistence.fast" ]]
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER"; then echo 'TEST_CONTAINER_BUSY'; exit 13; fi
if ss -lnt | grep -Eq ':(19491|19492)[[:space:]]'; then echo 'TEST_PORT_BUSY'; exit 14; fi
PASSWORD=$(openssl rand -hex 20)
KEY=$(openssl rand -hex 24)
api_pid=''
cleanup() {
  if [[ -n "$api_pid" ]]; then kill "$api_pid" 2>/dev/null || true; wait "$api_pid" 2>/dev/null || true; fi
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT
docker run --rm -d --name "$CONTAINER" -e POSTGRES_USER=eldoria049 -e POSTGRES_DB=eldoria049 \
  -e POSTGRES_PASSWORD="$PASSWORD" -p 127.0.0.1:$DB_PORT:5432 postgres:16-alpine >/dev/null
for i in $(seq 1 50); do
  if docker exec "$CONTAINER" pg_isready -U eldoria049 -d eldoria049 >/dev/null 2>&1; then break; fi
  sleep 1
done
for script in 001_init.sql 003_stone_axe.sql; do
  docker exec -i "$CONTAINER" psql -X -q -v ON_ERROR_STOP=1 -U eldoria049 -d eldoria049 < "$STAGE/$script"
done
docker exec "$CONTAINER" psql -X -q -v ON_ERROR_STOP=1 -U eldoria049 -d eldoria049 \
  -c "INSERT INTO eldoria_worlds(world_seed) VALUES (20261101) ON CONFLICT DO NOTHING; INSERT INTO eldoria_players(world_seed,identity_hash,avatar,wood,stone,herb,axe) VALUES (20261101,repeat('b',64),1,8,7,6,1);" >/dev/null
docker exec -i "$CONTAINER" psql -X -q -v ON_ERROR_STOP=1 -U eldoria049 -d eldoria049 < "$STAGE/004_skills_crafting.sql"
docker exec "$CONTAINER" psql -X -t -A -U eldoria049 -d eldoria049 -c \
  "SELECT wood,stone,herb,axe,archery_xp,bow FROM eldoria_players WHERE identity_hash=repeat('b',64)" | grep -qx '8|7|6|1|0|0'
ASPNETCORE_URLS=http://127.0.0.1:$API_PORT ELDORIA_INTERNAL_KEY="$KEY" \
  ELDORIA_POSTGRES_CONNECTION="Host=127.0.0.1;Port=$DB_PORT;Database=eldoria049;Username=eldoria049;Password=$PASSWORD" \
  "$STAGE/Eldoria.Persistence.fast" > "$STAGE/isolated-api-test.log" 2>&1 & api_pid=$!
ready=0
for i in $(seq 1 100); do
  if curl -fsS --max-time 2 -H "X-Eldoria-Server-Key: $KEY" http://127.0.0.1:$API_PORT/health >/dev/null 2>&1; then ready=1; break; fi
  if ! kill -0 "$api_pid" 2>/dev/null; then echo 'API_EXITED'; tail -25 "$STAGE/isolated-api-test.log"; exit 15; fi
  sleep 1
done
if [[ "$ready" != 1 ]]; then echo 'API_NOT_READY'; tail -20 "$STAGE/isolated-api-test.log"; exit 16; fi
curl -fsS -H "X-Eldoria-Server-Key: $KEY" http://127.0.0.1:$API_PORT/v1/world/20261101 > "$STAGE/before.json"
jq -e '.profiles[("b" * 64)].inventory.axe == 1 and .profiles[("b" * 64)].skills.archery == 0' "$STAGE/before.json" >/dev/null
jq '.profiles[("b" * 64)].inventory |= (. + {bow:1,arrow:8,shield:1}) | .profiles[("b" * 64)].skills = {archery:31,spear:3,defense:1}' "$STAGE/before.json" > "$STAGE/update.json"
curl -fsS -X PUT -H "X-Eldoria-Server-Key: $KEY" -H 'Content-Type: application/json' \
  --data-binary "@$STAGE/update.json" http://127.0.0.1:$API_PORT/v1/world/20261101 > "$STAGE/put-result.json"
curl -fsS -H "X-Eldoria-Server-Key: $KEY" http://127.0.0.1:$API_PORT/v1/world/20261101 > "$STAGE/after.json"
jq -e '.revision == 1 and .profiles[("b" * 64)].inventory.wood == 8 and .profiles[("b" * 64)].inventory.bow == 1 and .profiles[("b" * 64)].inventory.arrow == 8 and .profiles[("b" * 64)].skills.archery == 31 and .profiles[("b" * 64)].skills.spear == 3 and .profiles[("b" * 64)].skills.defense == 1' "$STAGE/after.json" >/dev/null
jq '.revision=1 | .profiles[("b" * 64)].skills.archery = -1' "$STAGE/after.json" > "$STAGE/invalid.json"
code=$(curl -sS -o /dev/null -w '%{http_code}' -X PUT -H "X-Eldoria-Server-Key: $KEY" \
  -H 'Content-Type: application/json' --data-binary "@$STAGE/invalid.json" http://127.0.0.1:$API_PORT/v1/world/20261101)
[[ "$code" == 400 ]]
echo 'TASK049 POSTGRES API PASS old player retained; migration, expanded items/skills roundtrip, invalid XP rejected'
