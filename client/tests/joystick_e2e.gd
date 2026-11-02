extends SceneTree
const JOYSTICK := preload("res://mobile_joystick.gd")
const DRIVER := preload("res://platform_input.gd")
var gamepad: Control
var driver: Node

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    driver = DRIVER.new()
    root.add_child(driver)
    gamepad = JOYSTICK.new()
    gamepad.size = Vector2(198,198)
    gamepad.moved.connect(driver.set_joystick)
    root.add_child(gamepad)
    await process_frame
    var center := gamepad.size * 0.5
    var index := 7
    gamepad.handle_touch(index,center,true,false)
    if driver.get_move_vector().length()>0.01:
        _fail("deadzone")
        return
    gamepad.handle_touch(index,center+Vector2(35,-35),true,true)
    var value: Vector2 = driver.get_move_vector()
    if value.x<0.36 or value.y>-0.36 or absf(value.length()-0.67)>0.08:
        _fail("diagonal analogue input incorrect: "+str(value))
        return
    gamepad.handle_touch(19,center+Vector2(-100,0),true,false)
    if driver.get_move_vector().distance_to(value)>0.001:
        _fail("second touch hijacked joystick")
        return
    gamepad.handle_touch(19,Vector2.ZERO,false,false)
    if gamepad.active_touch!=index:
        _fail("other finger release cancelled drag")
        return
    gamepad.handle_touch(index,center+Vector2(350,0),true,true)
    if driver.get_move_vector().distance_to(Vector2.RIGHT)>0.001:
        _fail("clamp at radius failed")
        return
    gamepad.handle_touch(index,Vector2(500,500),false,false)
    if driver.get_move_vector().length()>0.001 or gamepad.active_touch!=-1:
        _fail("touch release did not recenter")
        return
    gamepad.handle_touch(8,center+Vector2(2,2),true,false)
    gamepad.handle_touch(8,center+Vector2(4,1),true,true)
    if driver.get_move_vector().length()>0.001:
        _fail("deadzone jitter")
        return
    gamepad.handle_touch(8,center+Vector2(70,0),true,true)
    driver.clear_touch()
    gamepad.reset()
    if driver.get_move_vector().length()>0.001:
        _fail("disconnect left joystick stuck")
        return
    if gamepad.get_child_count()>0:
        _fail("joystick unexpectedly creates four buttons")
        return
    print("JOYSTICK PASS: diagonal vector, analogue acceleration, deadzone, radius clamp, second finger, release and disconnect")
    quit(0)

func _fail(reason: String) -> void:
    printerr("JOYSTICK FAIL: "+reason)
    quit(1)
