#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
TEMPLATES="$HOME/.local/share/godot/export_templates/4.5.2.stable"
JAVA_HOME="${JAVA_HOME:-$HOME/.local/jdk17}"
OUT="$ROOT/builds/windows"
ZIP="$ROOT/builds/Eldoria-Windows-0.1.1.zip"
test -x "$GODOT_BIN"
test -f "$TEMPLATES/windows_release_x86_64.exe"
test -x "$JAVA_HOME/bin/jar"
mkdir -p "$OUT"
"$GODOT_BIN" --headless --path "$ROOT/client" --editor --quit
"$GODOT_BIN" --headless --path "$ROOT/client" --export-release "Windows Desktop" "../builds/windows/Eldoria.exe"
test -s "$OUT/Eldoria.exe"
test -s "$OUT/Eldoria.pck"
# Inspect actual exported PE magic and machine x86-64, not just the file extension.
node - "$OUT/Eldoria.exe" <<'JS'
const fs = require("fs");
const file=fs.readFileSync(process.argv[2]);
if (file.toString("ascii",0,2)!=="MZ") throw new Error("Not PE executable");
const offset=file.readUInt32LE(0x3c);
if (file.toString("ascii",offset,offset+4)!=="PE\\0\\0".replace(/\\0/g,"\0")) throw new Error("Invalid PE header");
const machine=file.readUInt16LE(offset+4);
if (machine!==0x8664) throw new Error("Not Windows x86-64: "+machine.toString(16));
console.log("PASS Windows PE x86-64");
JS
cat > "$OUT/README.txt" <<'TXT'
ELDORIA 0.1.1 - Windows x86_64 PRE-ALPHA
Unzip the whole archive and run Eldoria.exe with Eldoria.pck next to it.
Windows: WASD (camera-relative), right mouse drag = orbit, E = Wave,
F11 = fullscreen, and choose a windowed resolution in the UI.
To join a shared world enter the IPv4 address of an ENet host and click Join world.
Host must allow UDP 7777 through firewall. A dedicated host may be started with
Godot 4.5.2 using: godot --headless --path client -- --dedicated-server
The current experiment has no persistent .NET backend or authentication.
This binary is not digitally code-signed: Windows SmartScreen may warn.
TXT
rm -f "$ZIP"
(cd "$OUT" && "$JAVA_HOME/bin/jar" --create --file "$ZIP" --no-manifest Eldoria.exe Eldoria.pck README.txt)
test -s "$ZIP"
"$JAVA_HOME/bin/jar" --list --file "$ZIP" | grep -Fx Eldoria.exe
"$JAVA_HOME/bin/jar" --list --file "$ZIP" | grep -Fx Eldoria.pck
"$JAVA_HOME/bin/jar" --list --file "$ZIP" | grep -Fx README.txt
echo "PASS: Windows x86-64 EXE+PCK+README ZIP"
ls -lh "$OUT/Eldoria.exe" "$OUT/Eldoria.pck" "$ZIP"
sha256sum "$ZIP"
