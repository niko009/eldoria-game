#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
TEMPLATES="$HOME/.local/share/godot/export_templates/4.5.2.stable"
JAVA_HOME="${JAVA_HOME:-$HOME/.local/jdk17}"
OUT="$ROOT/builds/windows"
ZIP="$ROOT/builds/Eldoria-Windows-0.5.3.zip"
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
cp "$ROOT/tools/EldoriaUpdater.ps1" "$OUT/EldoriaUpdater.ps1"
printf '%s' "0.5.3" > "$OUT/version.txt"
cat > "$OUT/Play Eldoria.cmd" <<'CMD'
@echo off
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0EldoriaUpdater.ps1" -GameDir "%~dp0"
CMD
cat > "$OUT/README.txt" <<'TXT'
ELDORIA 0.5.3 - Windows x86_64 PRE-ALPHA
Unzip the archive to a writable folder (do not run from inside ZIP).
Run "Play Eldoria.cmd" for automatic update check + launch.
You can also run Eldoria.exe directly; the game will check for updates on startup
and invoke the bundled updater if a newer Windows version is published.
The updater downloads from bacus.dev over HTTPS and verifies the ZIP SHA256
and size against the release manifest before replacing the game files.
Windows: WASD, hold right mouse button to orbit camera, E=Wave, F11 fullscreen.
Game server address is obtained automatically, over HTTPS, from bacus.dev.
Android has in-app update notifications; Android OS requires confirmation for APK installs.
Pre-alpha uses automatic anonymous identity and PostgreSQL world saving.
Build with B (select campfire/tent); V=green/red preview; F=gather.
Chop trees and gather herbs to clear ground. Android: Build mode > PLACE/CANCEL.
Optional performance statistics are collected every minute and can be disabled
using Performance data: OFF. No device IDs or account tokens are sent.
Windows binary is not Authenticode-signed; SmartScreen may warn.
TXT
rm -f "$ZIP"
(cd "$OUT" && "$JAVA_HOME/bin/jar" --create --file "$ZIP" --no-manifest Eldoria.exe Eldoria.pck EldoriaUpdater.ps1 'Play Eldoria.cmd' version.txt README.txt)
test -s "$ZIP"
"$JAVA_HOME/bin/jar" --list --file "$ZIP" | grep -Fx EldoriaUpdater.ps1
"$JAVA_HOME/bin/jar" --list --file "$ZIP" | grep -Fx 'Play Eldoria.cmd'
"$JAVA_HOME/bin/jar" --list --file "$ZIP" | grep -Fx version.txt
"$JAVA_HOME/bin/jar" --list --file "$ZIP" | grep -Fx Eldoria.exe
"$JAVA_HOME/bin/jar" --list --file "$ZIP" | grep -Fx Eldoria.pck
"$JAVA_HOME/bin/jar" --list --file "$ZIP" | grep -Fx README.txt
echo "PASS: Windows x86-64 EXE+PCK+README ZIP"
ls -lh "$OUT/Eldoria.exe" "$OUT/Eldoria.pck" "$ZIP"
sha256sum "$ZIP"
