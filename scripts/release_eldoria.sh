#!/usr/bin/env bash
# Eldoria single-command release on bacus-server.
# Usage: sudo /usr/local/bin/eldoria-release 0.5.5 feature/TASK-026V-visual-foundation --deploy
# Requires one-time export toolchain provisioning (see docs/ELDORIA_RELEASE_AUTOMATION.md).
set -Eeuo pipefail
umask 027

VERSION="${1:-}"
SOURCE_REF="${2:-}"
MODE="${3:---build-only}"
if [[ ! "$VERSION" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
  echo "Usage: $0 0.5.5 feature/TASK-026V-visual-foundation [--deploy|--build-only]" >&2; exit 2
fi
if [[ ! "$SOURCE_REF" =~ ^(feature|release)/[A-Za-z0-9._/-]+$ || "$SOURCE_REF" == *'..'* || "$SOURCE_REF" == */ ]]; then
  echo 'REF must be a GitHub feature/ or release/ branch, no shell syntax.' >&2; exit 2
fi
[[ "$MODE" == '--deploy' || "$MODE" == '--build-only' ]] || { echo "Invalid mode" >&2; exit 2; }
[[ "$EUID" == 0 ]] || { echo "Run as root (sudo) so the same script can activate systemd." >&2; exit 2; }

exec 9>/run/lock/eldoria-release.lock
flock -n 9 || { echo 'Another Eldoria release is running' >&2; exit 4; }

REPO='https://github.com/niko009/eldoria-game.git'
APP='/srv/bacus/apps'
SITE="$APP/bacus-dev/site/projects/eldoria"
ROOT="$APP/eldoria-releases"
DATE="$(date -u +%Y%m%dT%H%M%SZ)"
TAG="${VERSION//./}"
STAGE="$ROOT/$VERSION-$DATE"
WORK="$STAGE/repo"
BACKUP="/srv/bacus/backups/eldoria-pre-$VERSION-$DATE"
GODOT='/srv/bacus/apps/eldoria-test-server/godot'
SDK='/home/mbacus/.local/android-sdk'
JDK='/home/mbacus/.local/jdk17'
export JAVA_HOME="$JDK"
export PATH="$JDK/bin:$PATH"
GODOT_TEMPLATES='/home/mbacus/.local/share/godot/export_templates/4.5.2.stable'
APK="Eldoria-$VERSION-debug.apk"
ZIP="Eldoria-Windows-$VERSION.zip"
KEYSTORE='/home/mbacus/.local/share/godot/keystores/debug.keystore'
OVERRIDE="/etc/systemd/system/eldoria-ws-test.service.d/v${TAG}-release.conf"
LOG="$STAGE/release.log"
PREVIOUS="$(jq -r .version "$SITE/latest.json")"
OLD_CLIENT="$(jq -r .client_version "$SITE/server.json")"
[[ "$PREVIOUS" == "$OLD_CLIENT" ]] || { echo "Version mismatch on current production"; exit 5; }
[[ "$VERSION" != "$PREVIOUS" ]] || { echo "Refusing to overwrite the current release"; exit 5; }
[[ "$(printf '%s\n%s\n' "$PREVIOUS" "$VERSION" | sort -V | tail -1)" == "$VERSION" ]] || { echo "Refusing version downgrade"; exit 5; }

for f in "$GODOT" "$SDK/build-tools/35.0.0/apksigner" "$SDK/build-tools/35.0.0/aapt" "$JDK/bin/java" "$JDK/bin/jar" "$GODOT_TEMPLATES/android_debug.apk" "$GODOT_TEMPLATES/windows_release_x86_64.exe" "$KEYSTORE"; do
  [[ -e "$f" ]] || { echo "Missing toolchain asset: $f" >&2; exit 6; }
done
test -x "$GODOT" && test -x "$JDK/bin/jar"
test -x "$SDK/build-tools/35.0.0/apksigner"
test -x "$SDK/build-tools/35.0.0/aapt"
test -f "$SITE/Eldoria-$PREVIOUS-debug.apk"
systemctl is-active --quiet eldoria-persistence.service
systemctl is-active --quiet eldoria-ws-test.service

install -d -m 0750 -o mbacus -g mbacus "$ROOT" "$STAGE"
touch "$LOG"; chown mbacus:mbacus "$LOG"
exec > >(tee -a "$LOG") 2>&1
echo "ELDORIA_RELEASE_START $VERSION source=$SOURCE_REF mode=$MODE"
echo "Previous=$PREVIOUS"

# Source ref resolved from GitHub; this immutable checkout is kept for audit.
run_builder() {
  sudo -u mbacus env HOME=/home/mbacus USER=mbacus \
    JAVA_HOME="$JDK" ANDROID_SDK_ROOT="$SDK" ANDROID_HOME="$SDK" \
    XDG_DATA_HOME="$STAGE/godot-data" \
    GODOT_BIN="$GODOT" PATH="$JDK/bin:/usr/bin:/bin" "$@"
}
run_builder git clone --quiet --depth 1 --branch "$SOURCE_REF" "$REPO" "$WORK"
install -d -m 0750 -o mbacus -g mbacus "$STAGE/godot-data"
# Godot resolves export templates relative to XDG_DATA_HOME. Link the
# installed, verified templates into the isolated build sandbox BEFORE import.
install -d -m 0750 -o mbacus -g mbacus "$STAGE/godot-data/godot"
ln -s "$(dirname "$GODOT_TEMPLATES")" "$STAGE/godot-data/godot/export_templates"
HEAD="$(run_builder git -C "$WORK" rev-parse HEAD)"
echo "Source commit=$HEAD"
if [[ "$MODE" == --deploy && "$SOURCE_REF" == *'*'* ]]; then exit 6; fi

# Version stamping in a separate, archived release checkout, never in the user's
# feature branch. This keeps compatibility between Godot host, APK and Windows.
declare -a FILES=(
  "$WORK/client/main.gd"
  "$WORK/client/export_presets.cfg"
  "$WORK/tests/build_android_debug.sh"
  "$WORK/tests/build_windows.sh"
)
for f in "${FILES[@]}"; do test -s "$f"; done
old_source="$(sed -nE 's/^const CLIENT_VERSION := "([^"]+)".*/\1/p' "$WORK/client/main.gd" | head -1)"
[[ -n "$old_source" ]] || { echo "No source CLIENT_VERSION"; exit 6; }
# Only allow a known version or its dev candidate; no arbitrary string edits.
[[ "$old_source" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-dev)?$ ]] || exit 6
old_preset="$(sed -nE 's/^version\/name="([^"]+)"/\1/p' "$WORK/client/export_presets.cfg" | head -1)"
[[ "$old_preset" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "Invalid source export version: $old_preset" >&2; exit 6; }
# Feature branches are not version-stamped: their export preset can be older
# than the previous production even when their CLIENT_VERSION is a dev suffix.
[[ "$(printf '%s\n%s\n' "$old_preset" "$PREVIOUS" | sort -V | tail -1)" == "$PREVIOUS" ]] || {
  echo "Source preset is ahead of production; release manually" >&2; exit 6
}
for f in "${FILES[@]}"; do
  sed -i "s/${old_preset//./\\.}/$VERSION/g" "$f"
done
sed -i -E "s/^const CLIENT_VERSION := \"[^\"]+\"$/const CLIENT_VERSION := \"$VERSION\"/" "$WORK/client/main.gd"
# TASK-025 development branches intentionally disable public auto-connect.
# Release copies MUST re-enable discovery; never change the development branch.
sed -i -E 's/^const DEVELOPMENT_BUILD := true$/const DEVELOPMENT_BUILD := false/' "$WORK/client/main.gd"
grep -q '^const DEVELOPMENT_BUILD := false$' "$WORK/client/main.gd" || {
  echo 'Refusing release: public discovery still disabled'; exit 6
}
OLD_CODE="$("$SDK/build-tools/35.0.0/aapt" dump badging "$SITE/Eldoria-$PREVIOUS-debug.apk" | sed -nE "s/.*versionCode='([0-9]+)'.*/\1/p" | head -1)"
[[ "$OLD_CODE" =~ ^[0-9]+$ ]] || { echo "Cannot determine prior Android versionCode"; exit 6; }
NEXT_CODE="$((OLD_CODE + 1))"
sed -i "s|^version/code=.*|version/code=$NEXT_CODE|" "$WORK/client/export_presets.cfg"
sed -i -E "s/versionCode='[0-9]+'/versionCode='$NEXT_CODE'/g" "$WORK/tests/build_android_debug.sh"
if [[ "$(sed -nE 's/^const CLIENT_VERSION := "([^"]+)".*/\1/p' "$WORK/client/main.gd" | head -1)" != "$VERSION" ]]; then
  echo "Version stamping failed"; exit 6
fi
chown -R mbacus:mbacus "$WORK"

# Build tests do not write production resources or connect to the public server.
echo "GODOT_IMPORT"
run_builder "$GODOT" --headless --path "$WORK/client" --editor --quit >"$STAGE/import.log" 2>&1 || { tail -65 "$STAGE/import.log"; exit 7; }
for test in "tests/live_ui_smoke.gd" "ui_preview/preview_smoke.gd" "tests/task026v_diagnostics_e2e.gd" "tests/first_combat_e2e.gd"; do
  if [[ ! -f "$WORK/client/$test" ]]; then continue; fi
  echo "GODOT_SMOKE $test"
  # Test harness scripts are isolated: headless and without production WSS.
  run_builder "$GODOT" --headless --path "$WORK/client" --script "res://$test" -- --test-live-ui >"$STAGE/$(basename "$test").log" 2>&1 || { tail -65 "$STAGE/$(basename "$test").log"; exit 7; }
done
echo "EXPORT_ANDROID"
run_builder bash "$WORK/tests/build_android_debug.sh" >"$STAGE/android-build.log" 2>&1 || { tail -80 "$STAGE/android-build.log"; exit 8; }
echo "EXPORT_WINDOWS"
run_builder bash "$WORK/tests/build_windows.sh" >"$STAGE/windows-build.log" 2>&1 || { tail -80 "$STAGE/windows-build.log"; exit 8; }
test -s "$WORK/builds/$APK" && test -s "$WORK/builds/$ZIP"

# Signed updates must use exactly the previous cert so Android can install over
# the existing app. Do not print signing keys or keystore settings.
SIGNER="$SDK/build-tools/35.0.0/apksigner"
old_cert="$("$SIGNER" verify --print-certs "$SITE/Eldoria-$PREVIOUS-debug.apk" | sed -nE 's/^Signer #1 certificate SHA-256 digest: (.*)/\1/p')"
new_cert="$("$SIGNER" verify --print-certs "$WORK/builds/$APK" | sed -nE 's/^Signer #1 certificate SHA-256 digest: (.*)/\1/p')"
[[ -n "$old_cert" && "$old_cert" == "$new_cert" ]] || { echo 'Android signing certificate mismatch' >&2; exit 8; }
"$SIGNER" verify "$WORK/builds/$APK"
aapt_badging="$("$SDK/build-tools/35.0.0/aapt" dump badging "$WORK/builds/$APK")"
[[ "$aapt_badging" == *"name='dev.bacus.eldoria'"* && "$aapt_badging" == *"versionName='$VERSION'"* && "$aapt_badging" == *"arm64-v8a"* ]] || { echo "APK badging mismatch"; exit 8; }
[[ "$aapt_badging" == *"versionCode='$NEXT_CODE'"* ]] || { echo "APK versionCode mismatch"; exit 8; }

run_builder node "$WORK/tools/generate_manifest.js" "$VERSION" "${ELDORIA_RELEASE_NOTES:-Обновление Eldoria: графика, интерфейс и игровые улучшения.}" >"$STAGE/manifest.log"
run_builder sha256sum "$WORK/builds/$APK" "$WORK/builds/$ZIP" | tee "$STAGE/checksums.txt"
jq -e ".version == \"$VERSION\" and .schema == 1" "$WORK/builds/latest.json" >/dev/null
echo "BUILD_PASS SHA_MATCH CERT_MATCH"
if [[ "$MODE" == '--build-only' ]]; then
  echo "BUILD_ONLY_PASS archive=$STAGE"; exit 0
fi

# Back up first. Do not remove old APK/ZIP or restore an older DB automatically.
install -d -m 0700 "$BACKUP"
cp -a "$SITE/index.html" "$SITE/latest.json" "$SITE/server.json" "$BACKUP/"
cp -a /etc/systemd/system/eldoria-ws-test.service.d "$BACKUP/systemd-dropins"
docker exec eldoria-prod-postgres sh -c 'pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" -Fc --no-owner --no-acl' > "$BACKUP/world.pg.dump"
test -s "$BACKUP/world.pg.dump"
docker exec -i eldoria-prod-postgres pg_restore -l < "$BACKUP/world.pg.dump" | grep -q 'eldoria_worlds'
echo "BACKUP_PASS $BACKUP"

# Stage public assets before touching the live service.
install -o mbacus -g mbacus -m 0644 "$WORK/builds/$APK" "$SITE/$APK"
install -o mbacus -g mbacus -m 0644 "$WORK/builds/$ZIP" "$SITE/$ZIP"
install -o mbacus -g mbacus -m 0644 "$WORK/builds/latest.json" "$SITE/.latest-$VERSION.next"
jq --arg v "$VERSION" '.client_version=$v' "$SITE/server.json" >"$SITE/.server-$VERSION.next"
sed "s/${PREVIOUS//./\\.}/$VERSION/g" "$SITE/index.html" >"$SITE/.index-$VERSION.next"
chown mbacus:mbacus "$SITE"/.*-"$VERSION".next
sha256sum "$SITE/$APK" "$SITE/$ZIP"
[[ "$(systemctl is-active eldoria-persistence.service)" == active ]] || exit 10

ACTIVATED=0
rollback() {
  local code=$?
  trap - ERR INT TERM
  if [[ "$ACTIVATED" == 1 ]]; then
    echo "RELEASE_FAILED, AUTO_ROLLBACK"
    cp -a "$BACKUP/server.json" "$SITE/server.json"
    cp -a "$BACKUP/latest.json" "$SITE/latest.json"
    cp -a "$BACKUP/index.html" "$SITE/index.html"
    rm -f "$OVERRIDE"
    systemctl daemon-reload
    systemctl restart eldoria-ws-test.service || true
  fi
  echo "RELEASE_ERROR exit=$code stage=$STAGE backup=$BACKUP" >&2
  exit "$code"
}
trap rollback ERR INT TERM
# Drop-in after v054-craft.conf: version number grows, so the newest wins.
cat > "$OVERRIDE" <<EOF
[Service]
WorkingDirectory=$WORK
ExecStart=
ExecStart=$GODOT --headless --path $WORK/client -- --dedicated-server --websocket
EOF
chmod 0644 "$OVERRIDE"
ACTIVATED=1
systemctl daemon-reload
systemctl show eldoria-ws-test.service -p ExecStart --no-pager | grep -q "$WORK/client"
systemctl restart eldoria-ws-test.service
sleep 3
systemctl is-active --quiet eldoria-ws-test.service
ss -lnt | grep -q ':7788'
echo "NEW_GODOT_SERVICE_UP"
mv "$SITE/.server-$VERSION.next" "$SITE/server.json"
mv "$SITE/.latest-$VERSION.next" "$SITE/latest.json"
mv "$SITE/.index-$VERSION.next" "$SITE/index.html"
[[ "$(jq -r .client_version "$SITE/server.json")" == "$VERSION" ]]
[[ "$(jq -r .version "$SITE/latest.json")" == "$VERSION" ]]
for i in $(seq 1 6); do
  live_server="$(curl -fsS --connect-timeout 4 --max-time 10 -H 'Cache-Control: no-cache' "https://bacus.dev/projects/eldoria/server.json?r=$DATE" | jq -r .client_version || true)"
  live_manifest="$(curl -fsS --connect-timeout 4 --max-time 10 -H 'Cache-Control: no-cache' "https://bacus.dev/projects/eldoria/latest.json?r=$DATE" | jq -r .version || true)"
  [[ "$live_server" == "$VERSION" && "$live_manifest" == "$VERSION" ]] && break
  sleep 2
done
[[ "$live_server" == "$VERSION" && "$live_manifest" == "$VERSION" ]]
[[ "$(systemctl is-active eldoria-persistence.service)" == active ]]
echo "PUBLIC_VERSION_PASS $VERSION"
# Verify downloaded complete APK, not just HTTP HEAD.
curl -fsSL --retry 2 --max-time 180 "https://bacus.dev/projects/eldoria/$APK" | sha256sum | grep -q "^$(sha256sum "$WORK/builds/$APK" | cut -d' ' -f1) "
echo "PUBLIC_APK_SHA256_PASS"
trap - ERR INT TERM
echo "ELDORIA_RELEASE_SUCCESS $VERSION SHA=$HEAD BACKUP=$BACKUP"
