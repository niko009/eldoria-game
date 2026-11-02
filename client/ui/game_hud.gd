extends Control
class_name EldoriaGameHud

signal open_inventory
signal open_building
signal open_crafting
signal item_selected(item_id: String)
signal action_requested(action_id: String)
signal open_settings

const Style = preload("res://ui/ui_style.gd")
const State = preload("res://ui/mock_game_ui_state.gd")
const HotbarScene = preload("res://ui/Hotbar.tscn")

var state: MockGameUiState
var show_touch_controls := true
var preview_mode := true
var status_panel: PanelContainer
var status_detail: Label
var hotbar: EldoriaHotbar
var touch_layer: Control
var joystick: Control
var action_buttons: VBoxContainer
var top_actions: HBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel = PanelContainer.new()
	status_panel.add_theme_stylebox_override("panel", Style.panel(Color("172026", 0.82)))
	add_child(status_panel)
	var status_column := VBoxContainer.new()
	status_panel.add_child(status_column)
	status_column.add_child(Style.label("ELDORIA  ·  " + ("PREVIEW" if preview_mode else "ONLINE"), 18, Style.GOLD))
	status_detail = Style.label("", 13, Style.MUTED)
	status_column.add_child(status_detail)

	top_actions = HBoxContainer.new()
	top_actions.add_theme_constant_override("separation", 6)
	add_child(top_actions)
	for pair in [["Рюкзак", "inventory"], ["Строить", "build"], ["Крафт", "craft"], ["⚙", "settings"]]:
		var button := Button.new()
		button.text = pair[0]
		Style.button(button)
		button.pressed.connect(_open.bind(pair[1]))
		top_actions.add_child(button)

	hotbar = HotbarScene.instantiate()
	hotbar.state = state
	hotbar.item_selected.connect(func(id: String) -> void: item_selected.emit(id))
	add_child(hotbar)

	touch_layer = Control.new()
	touch_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(touch_layer)
	joystick = preload("res://ui/preview_joystick.gd").new()
	joystick.custom_minimum_size = Vector2(108, 108)
	touch_layer.add_child(joystick)
	action_buttons = VBoxContainer.new()
	action_buttons.add_theme_constant_override("separation", 6)
	touch_layer.add_child(action_buttons)
	for pair in [["Сбор", "gather"], ["Прыжок", "jump"], ["Бег", "sprint"], ["Рюкзак", "inventory"]]:
		var button := Button.new()
		button.text = pair[0]
		Style.button(button)
		button.custom_minimum_size = Vector2(78, 48)
		button.pressed.connect(_touch_action.bind(pair[1]))
		action_buttons.add_child(button)
	if state != null:
		state.changed.connect(refresh)
	resized.connect(_layout)
	refresh()
	_layout()

func refresh() -> void:
	if state == null or status_panel == null:
		return
	status_detail.text = "%s  ·  %s" % [state.selected_avatar.capitalize(), state.connection_status]
	touch_layer.visible = show_touch_controls
	_layout()

func _layout() -> void:
	if status_panel == null:
		return
	var insets := _safe_insets()
	var compact := size.x < 950 or size.y < 490
	status_panel.position = Vector2(insets.x, insets.y)
	status_panel.size = Vector2(minf(250, size.x * 0.34), 68)
	top_actions.position = Vector2(maxf(insets.x, size.x - top_actions.get_combined_minimum_size().x - insets.z), insets.y)
	hotbar.position = Vector2((size.x - hotbar.get_combined_minimum_size().x) * 0.5, size.y - hotbar.get_combined_minimum_size().y - insets.w)
	joystick.position = Vector2(insets.x, size.y - 108 - insets.w)
	action_buttons.position = Vector2(size.x - action_buttons.get_combined_minimum_size().x - insets.z, maxf(90, size.y - action_buttons.get_combined_minimum_size().y - insets.w))
	if compact:
		action_buttons.position.y = insets.y + 56

func _safe_insets() -> Vector4:
	var insets := Vector4(12, 12, 12, 12)
	if not OS.has_feature("mobile"):
		return insets
	var screen := DisplayServer.screen_get_size()
	if screen.x <= 0 or screen.y <= 0:
		return insets
	var safe := DisplayServer.get_display_safe_area()
	insets.x = maxf(12, float(safe.position.x) / screen.x * size.x + 8)
	insets.y = maxf(12, float(safe.position.y) / screen.y * size.y + 8)
	insets.z = maxf(12, float(screen.x - safe.end.x) / screen.x * size.x + 8)
	insets.w = maxf(12, float(screen.y - safe.end.y) / screen.y * size.y + 8)
	return insets

func _open(kind: String) -> void:
	match kind:
		"inventory": open_inventory.emit()
		"build": open_building.emit()
		"craft": open_crafting.emit()
		"settings": open_settings.emit()

func _touch_action(kind: String) -> void:
	if kind == "inventory":
		open_inventory.emit()
	else:
		action_requested.emit(kind)
