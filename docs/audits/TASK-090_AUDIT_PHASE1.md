# TASK-090 / A-04 — Phase 1: reproducible source inventory

**Base:** `feature/TASK-064-wildlife-hud` at `83f8f8d2a9bbfcd45197ae430e3cdb26466f8301`. **Status: IN_PROGRESS, not accepted.** This is a static inventory, **not** a completed art/UI review or a release.

## Verified inventory

Run `node tools/task090_asset_inventory.mjs` from the repository root. Output: [CSV](task090_asset_inventory.csv), containing source path, format, byte size, SHA-256, static reference candidates, declared provenance, and explicit unverified fields. The generator produces deterministic output (two successive SHA-256 values must match).

- 85 entries: 9 character files, 29 nature files, 19 audio files, 1 terrain file, 4 wildlife files, **23 procedural UI icon variants**. Binary `.bin` glTF buffers, `.import` sidecars, shader code, runtime procedural meshes, and world nodes are **not** independent rows. These counts are source files, **not** the number of objects visible in the game.
- Character assets: KayKit CC0 declaration in `client/assets/characters/LICENSE.txt`.
- Nature: Quaternius CC0 declaration in `client/assets/nature/License_Standard.txt`.
- Wildlife: individual provenance for Rabbit, Deer, Wolf in `client/assets/wildlife/LICENSE_SOURCES.md`; independently recheck external source licensing before redistribution.
- Terrain: generated texture provenance in `client/assets/terrain/PROVENANCE.md`.
- Audio: mixed generated/Kenney, see `client/assets/sfx/TASK062_LICENSE_SOURCES.md`.
- UI: item/equipment icons are GDScript draw primitives in `client/ui/item_icon.gd` and `client/ui/tool_icon.gd`. These are not PNGs. Asset scan therefore includes procedural variants explicitly.

**Limits:** `referenced_by` is a static text search, not proof of runtime use; `NOT_FOUND_IN_STATIC_SOURCE` does not mean unused. License fields are documented claims, not an independent legal audit. The script does not compute triangles, draw calls, FPS, icon legibility, mobile safe-area, or GLB rig validation. Screenshots are `NOT_CAPTURED` until actual Godot frames are attached. No models, textures, UI or gameplay files are changed.

## Remaining required audit and decisions

1. Capture actual Godot gameplay/HUD at 1280×720 Windows and Android aspect ratios 800×360, in day/night, inventory, crafting, combat, selected target and building. Compare icon silhouettes with the equipped meshes and check scroll/overlap.
2. Inventory runtime procedural meshes (tree depletion/stumps, resources, structures, projectiles, terrain, HUD and shader VFX); add object-level rows and verify GLB rig/animations and licensing.
3. Measure draw calls/triangles on High/Low, capture baseline frame times (physical Android still NOT VERIFIED), and produce two isolated same-camera visual style prototypes. Do not replace live assets without B-02/B-03 approval.

**Risk:** Current static inventory cannot establish visual quality or Android performance. This PR should remain Draft until all acceptance criteria are supported.
