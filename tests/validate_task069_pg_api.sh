#!/usr/bin/env bash
# TASK-069: isolated PostgreSQL + real .NET API; never touches production DB.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
API_BINARY="${TASK069_API_BINARY:?Set TASK069_API_BINARY to staged self-contained test binary}"
[[ -x "$API_BINARY" ]]
C=eldoria-task069-validation-pg
PG_PORT=19495
API_PORT=19496
DB=eldoria069
USER=eldoria069
if docker ps -a --format '{{.Names}}' | grep -Fxq "$C"; then echo 'TASK069_TEST_CONTAINER_BUSY'; exit 13; fi
if ss -lnt | grep -Eq ':(19495|19496)[[:space:]]'; then echo 'TASK069_TEST_PORT_BUSY'; exit 14; fi
PASS=$(openssl rand -hex 20)
KEY=$(openssl rand -hex 24)
api_pid=''
cleanup(){
  [[ -z "$api_pid" ]] || { kill "$api_pid" 2>/dev/null || true; wait "$api_pid" 2>/dev/null || true; }
  docker rm -f "$C" >/dev/null 2>&1 || true
}
trap cleanup EXIT
docker run --rm -d --name "$C" -e POSTGRES_USER="$USER" -e POSTGRES_DB="$DB" \
  -e POSTGRES_PASSWORD="$PASS" -p 127.0.0.1:$PG_PORT:5432 postgres:16-alpine >/dev/null
for i in $(seq 1 40); do
  if docker exec "$C" pg_isready -U "$USER" -d "$DB" >/dev/null 2>&1; then break; fi
  sleep 0.5
done
for sql in 001_init.sql 003_stone_axe.sql 004_skills_crafting.sql; do
  docker exec -i "$C" psql -X -q -v ON_ERROR_STOP=1 -U "$USER" -d "$DB" < "$ROOT/server/Eldoria.Persistence/sql/$sql"
done
# Existing player before schema migration must retain all earlier fields.
docker exec -i "$C" psql -X -q -v ON_ERROR_STOP=1 -U "$USER" -d "$DB" <<'SQL'
INSERT INTO eldoria_worlds(world_seed) VALUES(20261101) ON CONFLICT DO NOTHING;
INSERT INTO eldoria_players(world_seed,identity_hash,avatar,wood,stone,herb,axe,archery_xp)
VALUES(20261101,repeat('b',64),2,8,7,6,1,31);
SQL
docker exec -i "$C" psql -X -q -v ON_ERROR_STOP=1 -U "$USER" -d "$DB" < "$ROOT/server/Eldoria.Persistence/sql/005_hunting_inventory.sql"
rows=$(docker exec -i "$C" psql -X -t -A -U "$USER" -d "$DB" -c \
 "SELECT wood,stone,herb,axe,archery_xp,meat,hide,bone,leather_armor,grilled_meat FROM eldoria_players WHERE identity_hash=repeat('b',64)")
[[ "$rows" == '8|7|6|1|31|0|0|0|0|0' ]] || { echo 'TASK069_MIGRATION_LOST_EXISTING_DATA'; exit 1; }
ASPNETCORE_URLS="http://127.0.0.1:$API_PORT" ELDORIA_INTERNAL_KEY="$KEY" \
 ELDORIA_POSTGRES_CONNECTION="Host=127.0.0.1;Port=$PG_PORT;Database=$DB;Username=$USER;Password=$PASS" \
 "$API_BINARY" > /tmp/task069-api-integration.log 2>&1 & api_pid=$!
for i in $(seq 1 160); do
  if curl -fsS --max-time 1 -H "X-Eldoria-Server-Key: $KEY" "http://127.0.0.1:$API_PORT/health" >/dev/null 2>&1; then break; fi
  if ! kill -0 "$api_pid" 2>/dev/null; then echo API_EXITED; tail -15 /tmp/task069-api-integration.log; exit 1; fi
  sleep 0.75
done
if ! curl -fsS --max-time 5 -H "X-Eldoria-Server-Key: $KEY" "http://127.0.0.1:$API_PORT/health" >/dev/null 2>&1; then
  echo TASK069_API_NOT_READY
  tail -30 /tmp/task069-api-integration.log
  exit 8
fi
curl -fsS --max-time 5 -H "X-Eldoria-Server-Key: $KEY" "http://127.0.0.1:$API_PORT/v1/world/20261101" > /tmp/task069-old.json
jq -e '.profiles[("b" * 64)].inventory.meat == 0 and .profiles[("b" * 64)].inventory.wood == 8 and .profiles[("b" * 64)].skills.archery == 31' /tmp/task069-old.json >/dev/null
jq '.profiles[("b" * 64)].inventory |= (. + {meat:7,hide:4,bone:3,leather_armor:1,grilled_meat:2})' /tmp/task069-old.json > /tmp/task069-next.json
curl -fsS --max-time 12 -X PUT -H "X-Eldoria-Server-Key: $KEY" -H 'Content-Type: application/json' \
 --data-binary @/tmp/task069-next.json "http://127.0.0.1:$API_PORT/v1/world/20261101" >/tmp/task069-ack.json
curl -fsS --max-time 5 -H "X-Eldoria-Server-Key: $KEY" "http://127.0.0.1:$API_PORT/v1/world/20261101" > /tmp/task069-after.json
jq -e '(.revision == 1) and (.profiles[("b" * 64)].inventory | .meat == 7 and .hide == 4 and .bone == 3 and .leather_armor == 1 and .grilled_meat == 2)' /tmp/task069-after.json >/dev/null
jq -e '.profiles[("b" * 64)].skills.archery == 31 and .profiles[("b" * 64)].inventory.wood == 8' /tmp/task069-after.json >/dev/null
status=$(curl -sS --max-time 8 -o /dev/null -w '%{http_code}' -X PUT -H "X-Eldoria-Server-Key: $KEY" -H 'Content-Type: application/json' --data-binary @/tmp/task069-next.json "http://127.0.0.1:$API_PORT/v1/world/20261101")
[[ "$status" == 409 ]] || { echo "STALE_REVISION_NOT_409 status=$status"; exit 1; }
jq '.revision=1 | .profiles[("b" * 64)].inventory.grilled_meat=21' /tmp/task069-after.json > /tmp/task069-invalid.json
status=$(curl -sS --max-time 8 -o /dev/null -w '%{http_code}' -X PUT -H "X-Eldoria-Server-Key: $KEY" -H 'Content-Type: application/json' --data-binary @/tmp/task069-invalid.json "http://127.0.0.1:$API_PORT/v1/world/20261101")
[[ "$status" == 400 ]] || { echo "INVALID_INVENTORY_NOT_400 status=$status"; exit 1; }
rm -f /tmp/task069-old.json /tmp/task069-next.json /tmp/task069-after.json /tmp/task069-ack.json /tmp/task069-invalid.json
echo 'TASK069 POSTGRES API PASS migration retains old rows, new loot/food roundtrip, revision 409, invalid 400'
