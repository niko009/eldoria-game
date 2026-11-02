extends SceneTree
# Input.parse_input_event drives the REAL Godot Node._input route on a
# visible CanvasLayer Control; not just a direct helper call.
const JOYSTICK := preload("res://mobile_joystick.gd")
const DRIVER := preload("res://platform_input.gd")
var driver: Node
var joystick: Control
func _initialize() -> void:
    call_deferred("_run")
func _touch(index: int,pressed: bool, position: Vector2) -> void:
    var event := InputEventScreenTouch.new()
    event.index = index
    event.pressed = pressed
    event.position = position
    Input.parse_input_event(event)
func _drag(index: int, position: Vector2) -> void:
    var event := InputEventScreenDrag.new()
    event.index = index
    event.position = position
    event.relative = Vector2.ZERO
    Input.parse_input_event(event)
func _run() -> void:
    driver = DRIVER.new()
    root.add_child(driver)
    joystick = JOYSTICK.new()
    joystick.set_anchors_preset(Control.PRESET_TOP_LEFT)
    joystick.position = Vector2(24,180)
    joystick.size = Vector2(198,198)
    joystick.moved.connect(driver.set_joystick)
    root.add_child(joystick)
    await process_frame
    var center: Vector2 = joystick.global_position + joystick.size*0.5
    _touch(3,true,center)
    await process_frame
    _drag(3,center+Vector2(57,-28))
    await process_frame
    var v: Vector2 = driver.get_move_vector()
    if v.x < 0.6 or v.y > -0.2 or v.length() > 1.001:
        _fail("real viewport event failed "+str(v))
        return
    _touch(9,true,Vector2(1000,290))
    await process_frame
    if driver.get_move_vector().distance_to(v)>0.005:
        _fail("right-side touch hijacked left joystick")
        return
    _touch(3,false,center+Vector2(240,90))
    await process_frame
    if driver.get_move_vector().length()>0.001:
        _fail("release outside control did not recenter")
        return
    print("JOYSTICK GUI PASS: Godot viewport touch/drag + multitouch + release outside bounds")
    quit(0)
func _fail(reason: String) -> void:
    printerr("JOYSTICK GUI FAIL: "+reason)
    quit(1)
