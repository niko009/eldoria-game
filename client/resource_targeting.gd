extends RefCounted
## Client-side aim-assisted selection, never a replacement for server distance
## and remaining-quantity validation in _gather_on_server().
const MAX_GATHER_DISTANCE := 2.7
const MIN_AIM_DOT := 0.43 # forgiving ~64-degree cone on either side

static func choose(resources: Array[Dictionary], origin: Vector3,
        facing: Vector3, remaining: Dictionary, radius: float = MAX_GATHER_DISTANCE) -> int:
    var heading := Vector2(facing.x,facing.z)
    var has_heading := heading.length_squared() > 0.001
    if has_heading:
        heading = heading.normalized()
    var best_id := -1
    var best_score := -INF
    for resource in resources:
        var id: int = int(resource.get("id",-1))
        if id <= 0 or int(remaining.get(id,0)) <= 0:
            continue
        var at: Vector3 = resource["pos"]
        if absf(at.y-origin.y) > 4.0:
            continue
        var flat := Vector2(at.x-origin.x,at.z-origin.z)
        var distance := flat.length()
        if distance > radius:
            continue
        var alignment := 1.0
        if has_heading and distance > 0.12:
            alignment = heading.dot(flat/distance)
            if alignment < MIN_AIM_DOT:
                continue
        # Prefer the object actually looked at over an off-axis closer tree.
        # A small distance penalty makes overlapping objects deterministic.
        var score := alignment*4.0 - distance*0.25
        if score > best_score or (is_equal_approx(score,best_score) and
                (best_id < 0 or id < best_id)):
            best_score = score
            best_id = id
    return best_id