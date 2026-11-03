extends SceneTree
# TASK-037: compare spatial broadphase against the exact legacy all-obstacle
# scan, including deactivated trees, diagonal movement and camera collisions.
const WORLD := preload("res://forest_world.gd")
const QUERIES := 1250

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world: Node3D = WORLD.new()
    root.add_child(world)
    await process_frame
    if world.obstacle_positions.size() < 80:
        _fail("baseline forest obstacle count unexpectedly small")
        return
    var rng := RandomNumberGenerator.new()
    rng.seed = 409271
    var tested := 0
    var queries: Array[Dictionary] = []
    for j in QUERIES:
        var at := Vector2(rng.randf_range(-90, 90), rng.randf_range(-90, 90))
        var finish := at + Vector2(rng.randf_range(-14, 14), rng.randf_range(-14, 14))
        var radius: float = [0.35, 0.43, 1.3, 2.45][j%4]
        queries.append({"start":at, "end":finish, "radius":radius})
    for mode in range(2):
        if mode == 1:
            # Simulate depleted trees and ensure the index honors active flags.
            for i in range(0, world.obstacle_positions.size(), 5):
                world.obstacle_active[i] = false
        for q in queries:
            var start: Vector2 = q["start"]
            var finish: Vector2 = q["end"]
            var radius: float = q["radius"]
            if world.collides_at(start, radius) != _brute_collision(world, start, radius):
                _fail("collision mismatch: %s radius=%s mode=%d" % [start, radius,mode])
                return
            if world._sweep_hits(start, finish, radius) != _brute_sweep(world, start, finish, radius):
                _fail("sweep mismatch: %s -> %s radius=%s mode=%d" % [start,finish,radius,mode])
                return
            if tested % 10 == 0:
                var z: float = world.height_at(start.x,start.y) + 1.0
                var focus := Vector3(start.x, z+1.0, start.y)
                var camera := focus + Vector3(finish.x - start.x, 2.6, finish.y - start.y)
                var actual: Vector3 = world.camera_safe_target(focus, camera)
                var expected := _brute_camera(world, focus, camera)
                if actual.distance_to(expected) > 0.0005:
                    _fail("camera mismatch: %s vs %s" % [actual,expected])
                    return
            tested += 1
        # Additional actual player move/collision and camera safety checks.
        for q in queries.slice(0, 75):
            var start: Vector2 = q["start"]
            var finish: Vector2 = q["end"]
            var begin := Vector3(start.x, world.height_at(start.x,start.y)+1.0, start.y)
            var direction := Vector3(finish.x - start.x, 0, finish.y - start.y)
            if world.move_actor(begin,direction).distance_to(_brute_move(world,begin,direction)) > 0.001:
                _fail("move_actor deviated from legacy collision")
                return

    # Same Godot process, same generated queries; this is local CPU microbench,
    # not a measurement of real Android FPS or of the mobile GPU.
    var old_start := Time.get_ticks_usec()
    var hits_old := 0
    for repeat in range(6):
        for q in queries:
            if _brute_sweep(world,q["start"],q["end"],q["radius"]):
                hits_old += 1
    var elapsed_old := Time.get_ticks_usec()-old_start
    var indexed_start := Time.get_ticks_usec()
    var hits_new := 0
    for repeat in range(6):
        for q in queries:
            if world._sweep_hits(q["start"],q["end"],q["radius"]):
                hits_new += 1
    var elapsed_new := Time.get_ticks_usec()-indexed_start
    if hits_old != hits_new:
        _fail("benchmark result differs, old=%s indexed=%s" % [hits_old,hits_new])
        return
    print("TASK037 COLLISION PARITY PASS queries=", tested, " blockers=",world.obstacle_positions.size(), " active=",world.obstacle_active.count(true))
    print("TASK037 MICROBENCH sweep_scan_us=", elapsed_old, " sweep_grid_us=",elapsed_new,
        " ratio=",snappedf(float(elapsed_old)/maxf(1, float(elapsed_new)),0.01)," identical_hits=",hits_old)
    quit(0)

func _brute_collision(w: Node3D, pos: Vector2, radius: float) -> bool:
    for i in range(w.obstacle_positions.size()):
        if not w.obstacle_active[i]:
            continue
        var r: float = w.obstacle_radii[i] + radius
        if pos.distance_squared_to(w.obstacle_positions[i]) < r*r:
            return true
    return false

func _brute_sweep(w: Node3D, start: Vector2, finish: Vector2, radius: float) -> bool:
    var segment := finish - start
    var squared := segment.length_squared()
    if squared < 0.0000001:
        return _brute_collision(w,finish,radius)
    for i in range(w.obstacle_positions.size()):
        if not w.obstacle_active[i]:
            continue
        var center: Vector2 = w.obstacle_positions[i]
        var collision_radius: float = w.obstacle_radii[i] + radius
        var begin_dist := start.distance_squared_to(center)
        var end_dist := finish.distance_squared_to(center)
        if begin_dist < collision_radius * collision_radius and end_dist > begin_dist:
            continue
        var t := clampf((center-start).dot(segment)/squared,0.0,1.0)
        if (start+segment*t).distance_squared_to(center)<collision_radius*collision_radius:
            return true
    return false

func _brute_move(w: Node3D, current: Vector3, direction: Vector3) -> Vector3:
    var flat := Vector2(current.x,current.z)
    for step in [Vector2(direction.x, 0.0),Vector2(0.0,direction.z)]:
        if step.length_squared()<0.0000001:
            continue
        if not _brute_sweep(w,flat,flat+step,0.43):
            flat += step
        else:
            var safe := 0.0
            var unsafe := 1.0
            for i in range(9):
                var midpoint := (safe+unsafe)*0.5
                if _brute_sweep(w,flat,flat+step*midpoint,0.43):
                    unsafe=midpoint
                else:
                    safe=midpoint
            flat += step*safe
    return Vector3(flat.x,w.height_at(flat.x,flat.y)+1.0,flat.y)

func _brute_camera(w: Node3D, focus: Vector3, requested: Vector3) -> Vector3:
    var path := requested-focus
    if path.length() < 0.01:
        return requested
    var limit_t := 1.0
    var segment2 := Vector2(path.x,path.z)
    var flat_squared := segment2.length_squared()
    if flat_squared>0.0001:
        var start2 := Vector2(focus.x,focus.z)
        for i in range(w.obstacle_positions.size()):
            if not w.obstacle_active[i]:
                continue
            var radius: float = w.obstacle_radii[i]+0.35
            var offset: Vector2 = w.obstacle_positions[i]-start2
            var dot_t := clampf(offset.dot(segment2)/flat_squared,0.0,1.0)
            if (start2+segment2*dot_t).distance_squared_to(w.obstacle_positions[i])>radius*radius:
                continue
            var obstacle_height := 4.0 if w.obstacle_radii[i]>1.2 else 12.0
            var line_height := focus.y+path.y*dot_t
            var base_height: float = w.height_at(w.obstacle_positions[i].x,w.obstacle_positions[i].y)
            if line_height<base_height-0.5 or line_height>base_height+obstacle_height:
                continue
            var safe_t := 0.0
            var unsafe_t := dot_t
            for j in range(11):
                var middle := (safe_t+unsafe_t)*0.5
                if (start2+segment2*middle).distance_squared_to(w.obstacle_positions[i])<radius*radius:
                    unsafe_t=middle
                else:
                    safe_t=middle
            limit_t=minf(limit_t,maxf(0.12,safe_t-0.02))
    for sample in range(1,37):
        var t := float(sample)/36.0
        if t>=limit_t:
            break
        var at := focus+path*t
        if at.y<w.height_at(at.x,at.z)+0.35:
            limit_t=maxf(0.12,t-0.035)
            break
    return focus+path*limit_t

func _fail(why: String) -> void:
    printerr("TASK037 COLLISION FAIL: "+why)
    quit(1)
