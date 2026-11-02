extends Control
# Left-handed analog virtual joystick, using one captured touch index.
# On-screen position and shape are independent of the game resolution.
signal moved(direction: Vector2)
const RADIUS := 70.0
const THUMB_RADIUS := 27.0
const DEADZONE := 0.11
var active_touch := -1
var value := Vector2.ZERO
var _thumb_position := Vector2.ZERO

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    custom_minimum_size = Vector2(198,198)
    set_process_input(true)
    queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed and active_touch < 0 and get_global_rect().has_point(event.position):
            handle_touch(event.index, event.position - global_position, true, false)
            get_viewport().set_input_as_handled()
        elif not event.pressed and event.index == active_touch:
            handle_touch(event.index, event.position - global_position, false, false)
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag and event.index == active_touch:
        handle_touch(event.index, event.position - global_position, true, true)
        get_viewport().set_input_as_handled()

# Public pure-input seam for synthetic touch E2E; accepts LOCAL coordinates.
func handle_touch(index: int, local: Vector2, pressed: bool, drag: bool) -> void:
    if not pressed:
        if index != active_touch:
            return
        reset()
        return
    if active_touch < 0:
        if drag or not Rect2(Vector2.ZERO,size).has_point(local) or local.distance_to(size*0.5)>RADIUS+THUMB_RADIUS:
            return
        active_touch = index
    if active_touch != index:
        return
    var relative := local - size * 0.5
    var strength := minf(relative.length() / RADIUS,1.0)
    _thumb_position = relative.limit_length(RADIUS)
    if strength <= DEADZONE:
        value = Vector2.ZERO
    else:
        value = relative.normalized() * ((strength-DEADZONE)/(1.0-DEADZONE))
    moved.emit(value)
    queue_redraw()

func reset() -> void:
    active_touch = -1
    value = Vector2.ZERO
    _thumb_position = Vector2.ZERO
    moved.emit(Vector2.ZERO)
    queue_redraw()

func _exit_tree() -> void:
    reset()

func _draw() -> void:
    var center := size * 0.5
    draw_circle(center,RADIUS+9.0,Color(0.03,0.10,0.13,0.28))
    draw_circle(center,RADIUS,Color(0.12,0.22,0.27,0.38))
    draw_arc(center,RADIUS,0,TAU,68,Color(0.78,0.94,0.83,0.58),2.5,true)
    draw_circle(center+_thumb_position,THUMB_RADIUS+4.0,Color(0.04,0.08,0.08,0.28))
    draw_circle(center+_thumb_position,THUMB_RADIUS,Color(0.80,0.94,0.83,0.83))
    draw_arc(center+_thumb_position,THUMB_RADIUS,0,TAU,40,Color(0.92,1.0,0.92,0.89),2.0,true)
