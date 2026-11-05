#!/usr/bin/env bash
# Isolated mock-only persistence tests, never production.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
cd "$ROOT"
mkdir -p tests/logs
node tests/mock_persistence_conflicts.js > tests/logs/task069-mock-api.log 2>&1 & pid=$!
cleanup(){ kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; }
trap cleanup EXIT
sleep 0.4
kill -0 "$pid"
timeout 75 "$GODOT_BIN" --headless --path client --script res://tests/task069_persistence_recovery_e2e.gd -- --test-live-ui > tests/logs/task069-persistence.log 2>&1
cat tests/logs/task069-persistence.log
grep -q 'TASK069 PERSISTENCE PASS' tests/logs/task069-persistence.log
