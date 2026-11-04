# TASK-062 — positional sounds and combat/audio readability

**Date:** 4 November 2026. **Branch:** `feature/TASK-062-gameplay-audio`, based on TASK-061. Production remains v0.5.13. No release.

## Implemented

- Nine Kenney CC0 OGG foley clips and six original procedural WAVs integrated with existing audio preferences. Existing resource and construction WAVs retained. [Complete license/source manifest](../client/assets/sfx/TASK062_LICENSE_SOURCES.md).
- Player footsteps use two alternating grass sounds during actual local and remote movement, at most one step per 460 ms walking / 320 ms running (plus global voice cap); no steps when idle or airborne.
- Unarmed strikes, spear swings, shield actions, bow release, enemy hit, obstacles, wolf bites and wolf deaths play positionally from their corresponding visible/validated events.
- Mage heal, Rogue dash and Knight taunt audio play from their existing server-authoritative visual events. Invalid/refused actions and repeated dead-wolf snapshots do not create sound.
- Existing toggle Sound ON/OFF remains respected and persistent in `user://`; muting stops any active sounds immediately. No separate audio threads or additional RPCs.
- Max **6 concurrent AudioStreamPlayer3D voices** (same previous sound pool), 25-meter spatial max distance, attenuated volume (-15 dB footsteps, -10 dB wolves, -8 dB other SFX), kind-specific 90–280 ms throttles, automatic cleanup on completion/disconnect/mute. Extra sound events are discarded when voice pool fills, favoring stable Android performance.
- Sound trigger logic never modifies hit resolution, XP, inventory, network authority or database state.

## Known limits

- Wolf and magic sounds generated locally and are intentionally **synthetic placeholders**, not realistic wildlife recordings.
- This is initial functional sound coverage, not professional mixing or Android speaker validation. Playback verified using a real OpenGL Godot window with Dummy audio driver, which checks routing and stream integrity, **not audible acoustic quality**. Test on real Android/Windows before release.
- There is no continuous music or environmental ambience yet (next TASK-063).

## Tests

**4 November 2026: full `bash tests/run_dev_gameplay_e2e.sh` passed (exit 0).** Included real Xvfb/OpenGL TASK-062 audio with Dummy output, TASK-061 rigged wildlife, network co-op for two players, class abilities, crafting, Android UI, PostgreSQL and previous regressions. This verifies event/stream behavior; it is not an acoustic review or a physical Android FPS measurement.

- `client/tests/task062_game_audio_e2e.gd`, real OpenGL: all 19 categories including legacy sounds, loaded streams, spatial range, cooldown, six-voice cap, instant mute, server-originated spear/bow/wolf/death event routing, footstep throttle.
- `tests/run_dev_gameplay_e2e.sh`: new test in the Xvfb/OpenGL block, existing 2-client ENet and WebSocket, resource, crafting, skill and PostgreSQL persistence suite unchanged.
