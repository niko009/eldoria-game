extends SceneTree
const GAME := preload("res://Main.tscn")
const TARGETING := preload("res://resource_targeting.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var resources: Array[Dictionary] = [
        {"id":1,"kind":"wood","pos":Vector3(-0.5,0,-0.8)},
        {"id":2,"kind":"stone","pos":Vector3(0.0,0,-2.1)},
        {"id":3,"kind":"herb","pos":Vector3(0.0,0,1.0)},
        {"id":4,"kind":"wood","pos":Vector3(0.0,0,-3.3)}]
    var remaining := {1:4,2:3,3:1,4:5}
    if TARGETING.choose(resources,Vector3.ZERO,Vector3.FORWARD,remaining) != 2:
        _fail("looked-at rock not preferred to closer tree off-axis")
        return
    if TARGETING.choose(resources,Vector3.ZERO,Vector3.BACK,remaining) != 3:
        _fail("resource behind camera cannot be selected by looking at it")
        return
    if TARGETING.choose(resources,Vector3.ZERO,Vector3.RIGHT,remaining) != -1:
        _fail("out-of-cone resource selected")
        return
    remaining[2] = 0
    if TARGETING.choose(resources,Vector3.ZERO,Vector3.FORWARD,remaining) != 1:
        _fail("depleted resource remains targetable")
        return
    if TARGETING.choose(resources,Vector3.ZERO,Vector3.ZERO,remaining) != 1:
        _fail("no-heading safe fallback must use closest available resource")
        return

    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game.selected_avatar = 1
    game._host()
    game.set_physics_process(false)
    var id: int = game.own_id
    var world: Node3D = game.get_node("Eldoria_Forest")
    if game.resource_target_marker == null or not game.resource_target_marker.has_node("GroundRing"):
        _fail("no resource highlighting marker in playable world")
        return
    var target_id := -1
    for entry in world.resources:
        if entry["kind"] != "herb" or int(game.resource_remaining.get(entry["id"],0)) <= 0:
            continue
        var pos: Vector3 = entry["pos"]
        var standing := Vector3(pos.x,pos.y+0.3,pos.z+1.5)
        var facing := Vector3.FORWARD
        if TARGETING.choose(world.resources,standing,facing,game.resource_remaining) == int(entry["id"]):
            target_id = int(entry["id"])
            game.players[id].position = standing
            game.input_driver.yaw = 0.0
            break
    if target_id < 0:
        _fail("could not find a safe test flower in the world")
        return
    game._refresh_gather_hud()
    if game.selected_resource_id != target_id or not game.resource_target_marker.visible:
        _fail("highlighted resource is not the one camera points at")
        return
    if game.live_ui.gather_target_kind != "herb" or not game.live_ui.gather_target_hint.visible:
        _fail("Android gather hint missing from HUD")
        return
    game.input_driver.yaw = PI
    game._refresh_gather_hud()
    if game.selected_resource_id == target_id:
        _fail("resource still selected when player turns away")
        return
    game.input_driver.yaw = 0.0
    game._refresh_gather_hud()
    var before: int = int(game.resource_remaining[target_id])
    game._try_gather()
    if int(game.resource_remaining[target_id]) != before-1 or int(game.player_inventories[id]["herb"]) < 1:
        _fail("highlighted flower not collected by server")
        return

    # Desktop zoom: wheel event over the world, not GUI overlays.
    var input = game.input_driver
    var start_zoom: float = input.camera_distance
    var wheel := InputEventMouseButton.new()
    wheel.pressed = true
    wheel.button_index = MOUSE_BUTTON_WHEEL_UP
    game._unhandled_input(wheel)
    if input.camera_distance >= start_zoom:
        _fail("mouse wheel did not zoom camera in")
        return
    for i in 50:
        game._unhandled_input(wheel)
    if not is_equal_approx(input.camera_distance,input.CAMERA_MIN_DISTANCE):
        _fail("mouse zoom bypassed minimum distance")
        return
    wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
    for i in 60:
        game._unhandled_input(wheel)
    if not is_equal_approx(input.camera_distance,input.CAMERA_MAX_DISTANCE):
        _fail("mouse zoom bypassed maximum distance")
        return
    input.camera_distance = input.CAMERA_DEFAULT_DISTANCE

    # Android: second finger in upper-right viewport triggers pinch, not look.
    var first := InputEventScreenTouch.new()
    first.index=0; first.position=Vector2(620,120); first.pressed=true
    var second := InputEventScreenTouch.new()
    second.index=1; second.position=Vector2(740,120); second.pressed=true
    input.process_mobile_touch(first,Vector2(1000,400))
    input.process_mobile_touch(second,Vector2(1000,400))
    var spread := InputEventScreenDrag.new()
    spread.index=1; spread.position=Vector2(800,120); spread.relative=Vector2(60,0)
    input.process_mobile_touch(spread,Vector2(1000,400))
    if input.camera_distance >= input.CAMERA_DEFAULT_DISTANCE:
        _fail("two-finger spread did not zoom camera in")
        return
    var yaw_before: float = input.yaw
    spread.position=Vector2(770,120); spread.relative=Vector2(-30,0)
    input.process_mobile_touch(spread,Vector2(1000,400))
    if input.yaw != yaw_before:
        _fail("pinch rotated the camera")
        return
    first.pressed=false; second.pressed=false
    input.process_mobile_touch(first,Vector2(1000,400))
    input.process_mobile_touch(second,Vector2(1000,400))
    var after_pinch: float = input.camera_distance
    first.index=2; first.pressed=true; first.position=Vector2(120,300)
    second.index=3; second.pressed=true; second.position=Vector2(180,320)
    input.process_mobile_touch(first,Vector2(1000,400))
    input.process_mobile_touch(second,Vector2(1000,400))
    var left_drag := InputEventScreenDrag.new()
    left_drag.index=3; left_drag.position=Vector2(220,320); left_drag.relative=Vector2(40,0)
    input.process_mobile_touch(left_drag,Vector2(1000,400))
    if not is_equal_approx(after_pinch,input.camera_distance):
        _fail("two touches on joystick mistakenly zoomed the camera")
        return
    input.clear_touch()
    if not input._camera_touches.is_empty():
        _fail("touches remained active after cleanup")
        return

    # Color/state feedback predicts the same authoritative hit corridor.
    game.player_inventories[id]["arrow"] = 2
    game.players[id].position = Vector3(0,world.height_at(0,0)+1,0)
    var from: Vector3 = game.players[id].position+Vector3.UP*0.8
    var aim := Vector3.RIGHT
    for candidate in [Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
        if world.arrow_block_fraction(from,from+candidate*12.0)*12.0 > 3.0:
            aim = candidate
            break
    game.wolf_alive=true
    game.wolf_position=from+aim*2.5-Vector3.UP*0.65
    if game._spear_reticle_state(game.players[id].position,aim) != "target":
        _fail("spear has no ready reticle on target in front")
        return
    if game._spear_reticle_state(game.players[id].position,-aim) == "target":
        _fail("spear highlights enemy behind player")
        return
    if game._bow_reticle_state(from,aim) != "target":
        _fail("bow reticle does not turn green when arrow ray hits wolf")
        return
    game.live_ui.set_combat_equipment("bow")
    game.live_ui.set_combat_target_status("target")
    if not game.live_ui.combat_aim_help.text.contains("ЦЕЛЬ"):
        _fail("target highlight has no user-friendly hit confirmation")
        return
    game.player_inventories[id]["arrow"] = 0
    if game._bow_reticle_state(from,aim) != "no_ammo":
        _fail("empty bow reticle not marked red")
        return
    print("TASK055 TARGETING ZOOM PASS camera-facing collection, marker/HUD, authoritative gather, desktop wheel, Android pinch, bow/spear target colors")
    quit(0)

func _fail(reason: String) -> void:
    printerr("TASK055 TARGETING ZOOM FAIL: "+reason)
    quit(1)
