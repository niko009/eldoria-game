# TASK-062 audio provenance and rights

## Kenney source samples (Creative Commons CC0 1.0)

Nine short OGG sound effects from **Kenney Impact Sounds** and **Kenney RPG Audio**, both CC0; commercial use and distribution are permitted. Audio is stored in `client/assets/sfx/kenney/`, without runtime third-party requests. For this iteration the following individual files were used:

| Local OGG | Original Kenney pack path |
|---|---|
| step_grass_a.ogg | impact-sounds/Audio/footstep_grass_000.ogg |
| step_grass_b.ogg | impact-sounds/Audio/footstep_grass_002.ogg |
| punch.ogg | impact-sounds/Audio/impactPunch_medium_000.ogg |
| hit_wolf.ogg | impact-sounds/Audio/impactSoft_heavy_000.ogg |
| hit_shield.ogg | impact-sounds/Audio/impactMetal_light_000.ogg |
| hit_obstacle.ogg | impact-sounds/Audio/impactWood_medium_000.ogg |
| spear_swing.ogg | rpg-audio/Audio/knifeSlice.ogg |
| spear_hit.ogg | rpg-audio/Audio/knifeSlice2.ogg |
| gear_swish.ogg | rpg-audio/Audio/cloth1.ogg |

Original creator and licensing pages:
- https://kenney.nl/assets/impact-sounds
- https://kenney.nl/assets/rpg-audio
- https://creativecommons.org/publicdomain/zero/1.0/

A community mirror containing the unmodified audio files, manifest and preserved original license files was used to retrieve the specific OGGs:
https://github.com/GeorgeQLe/assets-sfx-combat

## Original synthetic effects, no third-party samples

These six WAV effects are synthesized directly from mathematical oscillators and deterministic pseudo-noise; **they are not authentic recordings**, particularly the wolf vocalizations:
`bow_twang.wav`, `wolf_snarl.wav`, `wolf_death.wav`, `mage_heal.wav`, `rogue_dash.wav`, `knight_taunt.wav`.

The complete reproducible generator is `tools/generate_task062_sfx.js` (Node.js built-ins only; run `node tools/generate_task062_sfx.js`). All files are mono PCM, 22,050 Hz, 16 bit, and short-lived. Wolf snarl/death are *placeholders* until high-quality appropriately licensed recordings are selected during an in-game audio review.

Keep this provenance record in any published source distribution.
