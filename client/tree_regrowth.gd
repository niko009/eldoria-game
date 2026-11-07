extends RefCounted
# Server-side, deterministic regrowth eligibility. Times are UTC Unix seconds,
# not process uptime; deadlines survive a dedicated server restart.
const REGROW_SECONDS := 300

static func deadline_on_depletion(now_unix: int) -> int:
    return maxi(0, now_unix) + REGROW_SECONDS

static func ready(deadline_unix: int, now_unix: int) -> bool:
    return deadline_unix > 0 and now_unix >= deadline_unix

static func blocked_by_building(resource_pos: Vector3, buildings: Dictionary, radii: Dictionary, clearance: float = 0.45) -> bool:
    var point := Vector2(resource_pos.x, resource_pos.z)
    for building in buildings.values():
        if not building is Dictionary:
            continue
        var kind := str(building.get("kind", ""))
        if not radii.has(kind):
            continue
        var center := Vector2(float(building.get("x", 0)), float(building.get("z", 0)))
        if point.distance_to(center) < float(radii[kind]) + clearance:
            return true
    return false
