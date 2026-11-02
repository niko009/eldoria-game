#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$HOME/.local/bin/Godot_v4.5.2-stable_linux.x86_64}"
SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/.local/android-sdk}}"
export JAVA_HOME="${JAVA_HOME:-$HOME/.local/jdk17}"
export PATH="$JAVA_HOME/bin:$PATH"
APK="$ROOT/builds/Eldoria-0.5.2-debug.apk"

test -x "$GODOT_BIN"
test -x "$SDK/build-tools/35.0.0/apksigner"
test -x "$SDK/build-tools/35.0.0/aapt"
test -f "$HOME/.local/share/godot/export_templates/4.5.2.stable/android_debug.apk"
mkdir -p "$ROOT/builds"
"$GODOT_BIN" --headless --path "$ROOT/client" --editor --quit
"$GODOT_BIN" --headless --path "$ROOT/client" --export-debug Android "../builds/Eldoria-0.5.2-debug.apk"
"$SDK/build-tools/35.0.0/apksigner" verify --verbose "$APK"
BADGING="$("$SDK/build-tools/35.0.0/aapt" dump badging "$APK")"
PERMISSIONS="$("$SDK/build-tools/35.0.0/aapt" dump permissions "$APK")"
[[ "$BADGING" == *"package: name='dev.bacus.eldoria'"* ]]
[[ "$BADGING" == *"versionCode='13' versionName='0.5.2'"* ]]
[[ "$BADGING" == *"native-code: 'arm64-v8a'"* ]]
[[ "$PERMISSIONS" == *"android.permission.INTERNET"* ]]
echo "PASS: signed Android v0.5.2 debug APK, ARM64, INTERNET permission"
ls -lh "$APK"
sha256sum "$APK"
