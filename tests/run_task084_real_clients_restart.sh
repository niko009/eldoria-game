#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
TMP="$(mktemp -d)"
host=""; a=""; b=""
cleanup() { for pid in "$host" "$a" "$b"; do if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null || true; fi; done; rm -rf "$TMP"; }
trap cleanup EXIT
export ELDORIA_SAVE_PATH="$TMP/world.json"
for phase in initial restored; do
  phase_args=(); [[ "$phase" == restored ]] && phase_args=(--restored)
  timeout 70 "$GODOT" --headless --path "$ROOT/client" --script res://tests/task084_restart_host_e2e.gd -- --dedicated-server --websocket "${phase_args[@]}" >"$TMP/host-$phase.log" 2>&1 & host=$!
  sleep 1
  ELDORIA_TEST_IDENTITY=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa timeout 60 "$GODOT" --headless --path "$ROOT/client" --script res://tests/task084_restart_client_e2e.gd -- --test-live-ui --mage "${phase_args[@]}" >"$TMP/mage-$phase.log" 2>&1 & a=$!
  ELDORIA_TEST_IDENTITY=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb timeout 60 "$GODOT" --headless --path "$ROOT/client" --script res://tests/task084_restart_client_e2e.gd -- --test-live-ui --knight "${phase_args[@]}" >"$TMP/knight-$phase.log" 2>&1 & b=$!
  if ! wait "$a" || ! wait "$b" || ! wait "$host"; then
    cat "$TMP/host-$phase.log" "$TMP/mage-$phase.log" "$TMP/knight-$phase.log"
    exit 1
  fi
  a=""; b=""; host=""
  for name in host mage knight; do
    if grep -E 'SCRIPT ERROR|Parse Error|TASK084 .*FAIL' "$TMP/$name-$phase.log"; then exit 1; fi
    grep -q "TASK084 .* ${phase^^} PASS" "$TMP/$name-$phase.log" || { cat "$TMP/$name-$phase.log"; exit 1; }
  done
  echo "TASK084 real WebSocket clients $phase PASS"
done