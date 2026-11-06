extends SceneTree
const GAME = preload("res://Main.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    var stick = game.live_ui.hud.joystick
    var touch := InputEventScreenTouch.new()
    touch.index = 1
    touch.pressed = true
    touch.position = Vector2(105,58)
    stick._gui_input(touch)
    if stick.direction.length() < 0.4:
        _fail("joystick did not start movement")
        return
    var attack_touch := InputEventScreenTouch.new()
    attack_touch.index = 2
    attack_touch.pressed = false
    attack_touch.position = Vector2(58,58)
    stick._gui_input(attack_touch)
    if stick.direction.length() < 0.4:
        _fail("second finger attack released movement joystick")
        return
    var drag := InputEventScreenDrag.new()
    drag.index = 2
    drag.position = Vector2(58,58)
    stick._gui_input(drag)
    if stick.direction.length() < 0.4:
        _fail("second finger drag hijacked joystick")
        return
    game.live_ui.hud._touch_action("attack")
    if stick.direction.length() < 0.4:
        _fail("attack action interrupted continuous movement")
        return
    touch.pressed = false
    stick._gui_input(touch)
    if stick.direction != Vector2.ZERO:
        _fail("movement continues after original finger is released")
        return
    game.selected_avatar = 2
    game.is_websocket_host = true
    game._host()
    game.set_physics_process(false)
    var id: int = game.own_id
    if id <= 0:
        _fail("local authority not started")
        return
    game.player_choices[id] = 2
    game.player_inventories[id] = game._empty_inventory()
    game.player_inventories[id]["wooden_staff"] = 1
    if not game._equip_combat_on_server(id,"wooden_staff"):
        _fail("crafted staff equip denied")
        return
    var world = game.get_node("Eldoria_Forest")
    game.players[id].position = Vector3(0,world.height_at(0,0)+1,0)
    game.wolf_alive = true
    game.wolf_health = 60
    game.wolf_position = Vector3(0,world.height_at(0,-4)+0.1,-4)
    game.pack_wolves.clear()
    game.hero_mana[id] = 100.0
    game.input_driver.yaw = 0.0
    game.input_driver.pitch = -0.1
    game.sprint_active = true
    game.last_attack_at.erase(id)
    game._try_attack()
    if game.wolf_health >= 60:
        _fail("staff attack during sprint did not damage wolf")
        return
    if not game.sprint_active:
        _fail("staff attack interrupted sprint toggle")
        return
    game.input_driver.set_joystick(Vector2(0.8,-0.4))
    var start_msec: int = Time.get_ticks_msec()
    if game._movement_axis_for_frame(start_msec) != Vector2.ZERO:
        _fail("attack animation must briefly pause movement")
        return
    if game._movement_axis_for_frame(start_msec + game.ATTACK_MOVE_PAUSE_MS) != Vector2(0.8,-0.4):
        _fail("movement did not resume with the original joystick direction")
        return
    if not game.sprint_active:
        _fail("attack pause cleared sprint state")
        return
    game.player_health[id] = 0
    game._try_attack()
    if game._movement_axis_for_frame(start_msec + game.ATTACK_MOVE_PAUSE_MS) != Vector2(0.8,-0.4):
        _fail("dead actor unexpectedly extended attack pause")
        return
    print("TASK082 MULTITOUCH PASS movement held while second finger attacks")
    game._disconnect()
    quit(0)
func _fail(reason: String) -> void:
    printerr("TASK082 MULTITOUCH FAIL " + reason)
    quit(1)