extends Control
class_name EldoriaPreviewJoystick

signal direction_changed(direction: Vector2)

var direction := Vector2.ZERO
var dragging := false
var touch_id := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(108, 108)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		dragging = event.pressed
		_set_direction(event.position if dragging else size * 0.5)
	elif event is InputEventMouseMotion and dragging:
		_set_direction(event.position)
	elif event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			dragging = true
			_set_direction(event.position)
		elif not event.pressed and event.index == touch_id:
			touch_id = -1
			dragging = false
			_set_direction(size * 0.5)
	elif event is InputEventScreenDrag and dragging and event.index == touch_id:
		_set_direction(event.position)

func _set_direction(point: Vector2) -> void:
	direction = ((point - size * 0.5) / (size.x * 0.35)).limit_length(1.0) if dragging else Vector2.ZERO
	direction_changed.emit(direction)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	draw_circle(center, size.x * 0.48, Color("1c262a", 0.55))
	draw_arc(center, size.x * 0.47, 0, TAU, 48, Color("d7b777", 0.6), 2)
	draw_circle(center + direction * size.x * 0.3, size.x * 0.22, Color("dfc28c", 0.72))
