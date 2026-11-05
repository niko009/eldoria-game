extends Node

# Platform-dependent input translation, not gameplay. Movement is shared.
var yaw := 0.0
var pitch := -0.45
var touch_move := Vector2.ZERO
var joystick_move := Vector2.ZERO
var _pressed_directions := {}
var _look_touch_id := -1
const CAMERA_MIN_DISTANCE := 4.8
const CAMERA_MAX_DISTANCE := 19.0
const CAMERA_DEFAULT_DISTANCE := 13.0
var camera_distance := CAMERA_DEFAULT_DISTANCE
var _camera_touches: Dictionary = {}
var _pinch_distance := 0.0

func change_zoom(step: float) -> void:
    if not is_finite(step):
        return
    camera_distance = clampf(camera_distance + step,CAMERA_MIN_DISTANCE,CAMERA_MAX_DISTANCE)

func get_move_vector() -> Vector2:
    return (Input.get_vector("move_left", "move_right", "move_forward", "move_back") + joystick_move + touch_move).limit_length()

func set_joystick(vector: Vector2) -> void:
    joystick_move = vector.limit_length()

func press_direction(direction: Vector2) -> void:
    _pressed_directions[direction] = true
    _recompute_touch()

func release_direction(direction: Vector2) -> void:
    _pressed_directions.erase(direction)
    _recompute_touch()

func clear_touch() -> void:
    _pressed_directions.clear()
    touch_move = Vector2.ZERO
    joystick_move = Vector2.ZERO
    _look_touch_id = -1
    _camera_touches.clear()
    _pinch_distance = 0.0

func _recompute_touch() -> void:
    touch_move = Vector2.ZERO
    for direction in _pressed_directions.keys():
        touch_move += direction
    touch_move = touch_move.limit_length()

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        _look(event.relative, 0.004)
    if OS.get_name() != "Android":
        return
    var game: Node = get_parent()
    if game != null and game.get("live_ui") != null and not game.get("live_ui").active_panel.is_empty():
        _camera_touches.clear()
        _pinch_distance = 0.0
        _look_touch_id = -1
        return
    process_mobile_touch(event,get_viewport().get_visible_rect().size)

func process_mobile_touch(event: InputEvent, viewport_size: Vector2) -> void:
    # Separate from OS detection so two-finger zoom can be tested headlessly.
    if event is InputEventScreenTouch:
        # Allow zoom in the world area instead of a narrow upper-right corner.
        # Keep the joystick and HUD action strip excluded.
        if event.pressed and event.position.y > viewport_size.y*0.16 and event.position.y < viewport_size.y*0.79 and not (event.position.x < viewport_size.x*0.24 and event.position.y > viewport_size.y*0.52) and not (event.position.x > viewport_size.x*0.73 and event.position.y > viewport_size.y*0.48):
            _camera_touches[event.index] = event.position
        else:
            _camera_touches.erase(event.index)
        if _camera_touches.size() == 2:
            _pinch_distance = _touch_gap()
            _look_touch_id = -1
        else:
            _pinch_distance = 0.0
        if not event.pressed and event.index == _look_touch_id:
            _look_touch_id = -1
        elif event.pressed and _look_touch_id == -1 and event.position.x > viewport_size.x*0.52:
            _look_touch_id = event.index
    elif event is InputEventScreenDrag:
        if _camera_touches.has(event.index):
            _camera_touches[event.index] = event.position
        if _camera_touches.size() == 2:
            var new_gap := _touch_gap()
            if _pinch_distance > 12.0 and new_gap > 12.0:
                camera_distance = clampf(camera_distance * _pinch_distance / new_gap,
                    CAMERA_MIN_DISTANCE,CAMERA_MAX_DISTANCE)
            _pinch_distance = new_gap
        elif event.index == _look_touch_id:
            _look(event.relative, 0.006)

func _touch_gap() -> float:
    var touch_ids := _camera_touches.keys()
    if touch_ids.size() != 2:
        return 0.0
    return Vector2(_camera_touches[touch_ids[0]]).distance_to(
        Vector2(_camera_touches[touch_ids[1]]))

func _look(relative: Vector2, sensitivity: float) -> void:
    yaw -= relative.x * sensitivity
    pitch = clampf(pitch - relative.y * sensitivity, -1.25, -0.05)
