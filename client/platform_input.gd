extends Node

# Platform-dependent input translation, not gameplay. Movement is shared.
var yaw := 0.0
var pitch := -0.45
var touch_move := Vector2.ZERO
var joystick_move := Vector2.ZERO
var _pressed_directions := {}
var _look_touch_id := -1

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
    if event is InputEventScreenTouch:
        if not event.pressed and event.index == _look_touch_id:
            _look_touch_id = -1
        elif event.pressed and _look_touch_id == -1 and event.position.x > get_viewport().get_visible_rect().size.x * 0.52:
            _look_touch_id = event.index
    elif event is InputEventScreenDrag and event.index == _look_touch_id:
        _look(event.relative, 0.006)

func _look(relative: Vector2, sensitivity: float) -> void:
    yaw -= relative.x * sensitivity
    pitch = clampf(pitch - relative.y * sensitivity, -1.25, -0.05)
