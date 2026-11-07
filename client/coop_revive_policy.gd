extends RefCounted

# Pure server-side policy for TASK-095. No client-supplied health or positions.
# This module does not yet change the live death/respawn flow.
const REVIVE_WINDOW_MS := 12000
const REVIVE_HOLD_MS := 1800
const REVIVE_DISTANCE_M := 2.5
const REVIVE_HEALTH := 30

static func eligible(reviver_id: int, downed_id: int, now_ms: int,
        downed_until_ms: int, reviver_hp: int, downed_hp: int,
        reviver_position: Vector3, downed_position: Vector3,
        line_of_sight: bool, interrupted: bool) -> bool:
    if reviver_id <= 0 or downed_id <= 0 or reviver_id == downed_id:
        return false
    if now_ms >= downed_until_ms or downed_until_ms <= 0:
        return false
    if reviver_hp <= 0 or downed_hp != 0 or interrupted:
        return false
    if not reviver_position.is_finite() or not downed_position.is_finite():
        return false
    if reviver_position.distance_to(downed_position) > REVIVE_DISTANCE_M:
        return false
    return line_of_sight

static func hold_complete(start_ms: int, now_ms: int, last_interrupted_ms: int) -> bool:
    return start_ms >= 0 and now_ms >= start_ms + REVIVE_HOLD_MS and last_interrupted_ms < start_ms