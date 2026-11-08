#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
godot="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT
for phase in initial restored; do
 ELDORIA_SAVE_PATH="$dir/world.json" timeout 35 "$godot" --headless --path "$root/client" --script res://tests/task087_five_arrows_persistence_e2e.gd -- --test-live-ui --"$phase" >"$dir/$phase.log" 2>&1 || { tail -40 "$dir/$phase.log";exit 1;}
 if [ "$phase" = initial ]; then marker='TASK087 FIVE ARROWS INITIAL PASS'; else marker='TASK087 FIVE ARROWS RESTART PASS'; fi
 grep -q "$marker" "$dir/$phase.log" || { tail -35 "$dir/$phase.log";exit 1;}
 if grep -E 'SCRIPT ERROR|Parse Error|FIVE ARROWS FAIL' "$dir/$phase.log";then exit 1;fi
 echo "5-ARROW $phase PASS"
done
echo 'TASK087 ARROW SERVER HUD RESTART PASS'
