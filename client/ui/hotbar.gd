extends PanelContainer
class_name EldoriaHotbar

signal item_selected(item_id: String)

const Style = preload("res://ui/ui_style.gd")
const State = preload("res://ui/mock_game_ui_state.gd")
const Icon = preload("res://ui/tool_icon.gd")

# Keep the crafted axe on keyboard/touch slot 4 for backwards-compatible controls.
const SLOTS := ["unarmed", "sword", "pickaxe", "axe", "hammer", "bow"]

var state: MockGameUiState
var row: HBoxContainer
var slot_buttons: Dictionary = {}
var slot_icons: Dictionary = {}

func _ready() -> void:
	add_theme_stylebox_override("panel", Style.panel(Color("172026", 0.83), Color("6e6c5d")))
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	add_child(row)
	for index in SLOTS.size():
		var tool_id: String = SLOTS[index]
		var slot := Button.new()
		slot.name = "ToolSlot_%s" % tool_id
		slot.text = "" # Absolutely no resource numbers or text badges in the hotbar.
		slot.custom_minimum_size = Vector2(56, 58)
		slot.focus_mode = Control.FOCUS_NONE
		slot.pressed.connect(_on_slot_pressed.bind(tool_id))
		row.add_child(slot)
		var icon := Icon.new()
		icon.name = "ToolIcon_%s" % tool_id
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)
		# Button isn't a Container: place children explicitly in local coordinates.
		# Center anchors caused Godot to add half the slot width to our offsets,
		# drawing silhouettes below and to the right of their buttons.
		icon.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		icon.position = Vector2(5, 6)
		icon.size = Vector2(46, 46)
		slot_buttons[tool_id] = slot
		slot_icons[tool_id] = icon
	if state != null:
		state.changed.connect(refresh)
	refresh()

func _on_slot_pressed(tool_id: String) -> void:
	if state != null and state.can_select_tool(tool_id):
		item_selected.emit(tool_id)

func refresh() -> void:
	if row == null or state == null:
		return
	for index in SLOTS.size():
		var tool_id: String = SLOTS[index]
		var slot: Button = slot_buttons[tool_id]
		var available: bool = state.can_select_tool(tool_id)
		var selected: bool = state.selected_item == tool_id
		slot.disabled = not available
		slot.tooltip_text = "%d · %s" % [index + 1, State.TOOLS[tool_id]["name"]]
		Style.button(slot, selected)
		slot.custom_minimum_size = Vector2(56, 58)
		var icon: Control = slot_icons[tool_id]
		icon.configure(tool_id, available, selected)
