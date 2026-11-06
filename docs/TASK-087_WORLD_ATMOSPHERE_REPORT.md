# TASK-087.07 / TASK-087.08 — World atmosphere

Work branch: `feature/TASK-087-world-atmosphere`. Base: `a16a036`,
`origin/feature/TASK-064-wildlife-hud`. No merge or release authorized.

## A. Baseline audit

The current base already has eight Quaternius tree meshes, a rolling heightfield,
a path, pond, alpine backdrop, gatherable vegetation and a day/night transition.
It is not an empty scene. The remaining visual weaknesses are long empty gaps
between trees, disconnected plants without an understory, uniform trail edges,
little environmental storytelling, and an unshaded mountain backdrop that stays
bright while the ground and actors become difficult to read at night.

Baseline images are actual Godot 4.5.2 Windows OpenGL frames at 1024×576 on
Intel UHD Graphics 730. `client/atmosphere/Survey.tscn` instantiates the real
`Main.tscn` offline with two actors, a wolf, a tent and a campfire. It does not
host, connect to production, or save a world. Cameras, actors, resolution and
sampling are identical in Before/After. The baseline is a fresh detached
worktree at `a16a036`, with only the survey harness copied into it.

- [High baseline and measurements](../tests/artifacts/task087/before-high/metrics.json)
- [Low baseline and measurements](../tests/artifacts/task087/before-low/metrics.json)
- [Day clearing](../tests/artifacts/task087/before-high/clearing_day.png)
- [Night forest](../tests/artifacts/task087/before-high/forest_night.png)
- [Night encounter](../tests/artifacts/task087/before-high/encounter.png)

The baseline contract records 355 resources and 164 obstacle footprints in
`client/tests/task087_world_baseline.json`. The hashes cover ordered IDs, types,
positions, amounts, batch/index links, obstacle links and obstacle positions/radii.

MCP server/addon 2026.10.20.1 was verified against this task's actual worktree.
The built-in session had a stale port-bind error. A fresh local FastMCP STDIO
session restored the localhost bridge without publishing a port. Project
inspection, editor play, real runtime screenshot and stop succeeded. Addon and
probe are temporary local tools; they are not part of the shipped project.

`docs/TASK-087_GAMEPLAY_WORLD_UI_POLISH.md` is absent from the requested base.
The attached TASK-087.07/.08 specification is the scope authority.

## Remaining acceptance work

Implementation, final visual review, focused tests, two-client tests,
performance comparison and PR are recorded in the following development stage.
Physical Android is unavailable: `adb devices -l` lists no devices. Windows Low
is a profile check, not a phone performance or touch test.
