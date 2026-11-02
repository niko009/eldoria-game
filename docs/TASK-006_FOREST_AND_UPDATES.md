# TASK-006 — Eldoria Forest + self-updates (2026-11-01)

**Current published build: v0.2.1** (the initial v0.2.0 introduced updates, v0.2.1 adjusts forest colors and validates the next release manifest).

## Forest v0.2.0
- Fully procedural stylized landscape `client/forest_world.gd`: rolling hills, grassland vertex colors, winding trail, pond, stones, flowers, three tree silhouettes (broadleaf, birch, pine), glowing waypoint, warm sun, sky and mist.
- Scene generated deterministically with fixed seed across Windows and Android. No external asset licensing or texture downloads.
- Center 13m remains level: existing network movement/spawn tests still pass. These are visual meshes, not yet physical terrain collision or editable/destructible trees.
- Android uses lighter foliage mesh and disables shadows by default. Performance, FPS and visual appearance still require real device profiling.
- Real Godot OpenGL Compatibility screenshot taken in Linux Xvfb software renderer: `forest-preview.png` on the website. **Not concept art.**

## Update architecture
At game startup, Windows and Android make HTTPS GET to `https://bacus.dev/projects/eldoria/latest.json` and compare semantic version. Manifest includes exact release filename, size and SHA-256.

- **Windows**: bundled `EldoriaUpdater.ps1` runs separately, downloads ZIP from the fixed bacus.dev release prefix, validates SHA-256 and byte size, checks required EXE/PCK/updater files, backs up previous files, waits for game process exit, replaces files and restarts the game. `Play Eldoria.cmd` checks updates even before game startup. Direct `Eldoria.exe` also checks at launch and invokes updater when a newer release is detected. Install to writable folder, not Program Files. The executable is **unsigned** and Windows SmartScreen can warn. SHA-256 check protects against corrupted release; it does not replace publisher code signing or a signed release manifest.
- **Android**: Godot checks for updates automatically and shows an Update button if a new APK exists. Android opens the HTTPS APK link, and user must approve installation through OS/browser. Android **cannot silently self-install** an updated APK without privileged device management. The debug signing key and package ID must remain the same; otherwise APK in-place upgrades fail. Godot Play export would require Play In-App Updates if published through Play.
- Test runner `tools/generate_manifest.js 0.2.0` makes manifest from real file hashes/sizes after successful builds. Update the static JSON on bacus.dev for each release; existing v0.1.3 clients do not contain auto-updater and must upgrade once manually.

## Tests and limits
- Headless network ENet, dedicated 2-player, LAN discovery and WebSocket E2Es: PASS.
- Forest scene parsing, >60 canopy mesh leaves and spawn clearing consistency: PASS.
- Update manager manifest validation tests: matching/new version, host allowlist and SHA format: PASS.
- Windows ZIP PE x64, EXE+PCK+updater+cmd+version, Android debug APK signature: PASS.
- PowerShell `-TestOnly` started from an installed-version fixture `0.2.0`, found `0.2.1` on the live website, downloaded ZIP, and validated checksum, byte length and contents: PASS (Linux PowerShell). Real Windows in-place replacement and relaunch remain untested.
- Real Windows update replacement, Windows GPU visual quality, Android OTA user flow and device performance: **NOT TESTED on physical hardware**.
- Public Godot server remains a test, no accounts, world persistence or production anti-cheat.
