# TASK-002 — Android debug export (2026-11-01)

**Build PASS, packaging/signature checks PASS, hardware test PENDING.** This is not a release ready for Google Play.

## Toolchain used

- Godot **4.5.2 stable** (GDScript); matching export templates `4.5.2.stable`.
- OpenJDK **17.0.21**; Android command-line tools; SDK Platform **35**; Build Tools **35.0.0**; platform-tools.
- `client/export_presets.cfg`: package `dev.bacus.eldoria`, versionName `0.1.0`, versionCode `1`, `arm64-v8a`, debug signature, `INTERNET` permission, GL Compatibility renderer.
- The project explicitly enables `rendering/textures/vram_compression/import_etc2_astc=true`, required for Android export on x86-64 Linux.

## Reproduce

Configure **Godot Editor Settings → Export → Android**: set Java SDK path to JDK 17, Android SDK path to the installed SDK, and configure a **local debug keystore** (do not commit private keys). Install matching Godot export templates.

From the repo root:

```bash
ANDROID_SDK_ROOT=/path/to/android-sdk GODOT_BIN=/path/to/godot bash tests/build_android_debug.sh
```

Result: `builds/Eldoria-0.1.0-debug.apk` (ignored by Git, kept outside source control). On the Local Coder environment: `/home/coder/eldoria-task001/builds/Eldoria-0.1.0-debug.apk`.

## Verified artefact

- File size: approximately **27 MB**.
- `apksigner verify --verbose`: **Verifies**, APK Signature Scheme **v2/v3**.
- `aapt dump badging`: `dev.bacus.eldoria`, `0.1.0` (`1`), minimum Android API **24**, target API **35**, native ABI **arm64-v8a**.
- `aapt dump permissions`: `android.permission.INTERNET` present.
- SHA-256: `c1c8f220cf99dab6d9a5dc24f6dcdd76fd932403ebd1ab078dacf1e47ca695ad`.
- `adb devices -l`: **no Android devices connected**. No physical Android installation, 3D rendering, frame rate, touch or LAN multiplayer verified.

## Physical-device acceptance gate (pending)

Install the APK on a real ARM64 Android phone. Start the Godot host on a PC attached to the same LAN, allow inbound **UDP 7777**, enter its LAN IPv4 in the phone, join, move both players, disconnect and reconnect; verify screen orientation, touch controls, FPS, battery and temperature. Capture actual phone logs (`adb logcat`) and results. Do not publish the APK as an end-user release until these tests pass.