extends SceneTree
const FOREST := preload("res://forest_world.gd")
const JUMP := preload("res://jump_motion.gd")
const PROFILE := preload("res://avatar_profile.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var forest: Node3D = FOREST.new()
    root.add_child(forest)
    await process_frame
    if forest.obstacle_positions.is_empty():
        _fail("no camera blockers")
        return
    var center: Vector2 = forest.obstacle_positions[0]
    var radius: float = forest.obstacle_radii[0]
    var y: float = forest.height_at(center.x,center.y)+1.7
    var eye := Vector3(center.x-(radius+4),y,center.y)
    var goal := Vector3(center.x+(radius+4),y,center.y)
    var clipped: Vector3 = forest.camera_safe_target(eye,goal)
    if clipped.distance_to(goal) < 0.4:
        _fail("camera failed to stop before tree/rock")
        return
    if clipped.x > center.x-radius-0.1:
        _fail("camera clipped through blocker")
        return
    var no_obstacle_eye := Vector3(0, 5, 0)
    var no_obstacle_goal := Vector3(0, 8, 0)
    if forest.camera_safe_target(no_obstacle_eye,no_obstacle_goal).distance_to(no_obstacle_goal) > 0.001:
        _fail("camera unnecessarily clipped clear path")
        return
    if absf(JUMP.elevation(JUMP.INITIAL_SPEED/JUMP.GRAVITY)-1.285714) > 0.02:
        _fail("jump apex incorrect")
        return
    if JUMP.elevation(JUMP.DURATION+0.01) != 0.0:
        _fail("jump did not return to ground")
        return
    var origin := Vector3(0,1,0)
    if forest.valid_remote_step(origin,Vector3(0,2.2,0)):
        _fail("server allows unauthorized jump")
        return
    if not forest.valid_remote_step(origin,Vector3(0,2.2,0),0.43,1.2):
        _fail("server rejects legitimate airborne movement")
        return
    var original := PROFILE.read_choice()
    if PROFILE.save_choice(2) != OK or PROFILE.read_choice()!=2:
        _fail("avatar choice not persisted")
        return
    if PROFILE.save_choice(99) != ERR_INVALID_PARAMETER:
        _fail("invalid avatar saved")
        return
    PROFILE.save_choice(original)
    print("CAMERA + JUMP + PROFILE PASS: obstacle occlusion, clear view, ballistic arc, server height validation, avatar persistence")
    quit(0)

func _fail(message: String) -> void:
    printerr("CAMERA/PROFILE FAIL: "+message)
    quit(1)
