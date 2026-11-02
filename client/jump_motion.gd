extends RefCounted
# Time-based ballistic hop; horizontal obstacles stay solid.
const INITIAL_SPEED := 6.0
const GRAVITY := 14.0
const DURATION := (2.0 * INITIAL_SPEED) / GRAVITY
const COOLDOWN_MSEC := 1050

static func elevation(seconds: float) -> float:
    if seconds < 0.0 or seconds >= DURATION:
        return 0.0
    return maxf(0.0, INITIAL_SPEED*seconds-0.5*GRAVITY*seconds*seconds)
