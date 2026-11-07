#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
for phase in initial restored verified; do
  ELDORIA_SAVE_PATH="$tmp/world.json" timeout 60 "$GODOT_BIN" --headless --path "$ROOT/client" --script res://tests/task087_tree_regrowth_server_e2e.gd -- --test-live-ui --"$phase" >"$tmp/$phase.log" 2>&1 || { tail -50 "$tmp/$phase.log"; exit 1; }
  grep -q "TASK087 REGROW ${phase^^} PASS" "$tmp/$phase.log" || { tail -50 "$tmp/$phase.log"; exit 1; }
  if grep -E 'SCRIPT ERROR|Parse Error|TASK087 REGROW FAIL' "$tmp/$phase.log"; then exit 1; fi
  echo "$phase OK"
done
node - "$tmp/world.json" <<'JS'
const fs=require('fs'),data=JSON.parse(fs.readFileSync(process.argv[2]));
if(data.schema!==1 || Object.keys(data.regrowth_at||{}).length!==0) process.exit(1);
console.log('JSON REGROWTH FINAL PASS');
JS
