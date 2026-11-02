extends PanelContainer
class_name EldoriaHotbar

signal item_selected(item_id: String)

const Style = preload("res://ui/ui_style.gd")
const State = preload("res://ui/mock_game_ui_state.gd")
const SLOTS := ["wood", "stone", "herb", "axe"]

var state: MockGameUiState
var row: HBoxContainer

func _ready() -> void:
	add_theme_stylebox_override("panel", Style.panel(Color("172026", 0.8), Color("6e6c5d")))
	row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	add_child(row)
	if state != null:
		state.changed.connect(refresh)
	refresh()

func refresh() -> void:
	if row == null or state == null:
		return
	for child in row.get_children():
		child.queue_free()
	for index in SLOTS.size():
		var item_id: String = SLOTS[index]
		var item: Dictionary = State.ITEMS[item_id]
		var slot := Button.new()
		slot.text = "%s%s\n%d" % [item["symbol"], " ✓" if item_id == "axe" and state.equipped_axe else "", state.amount(item_id)]
		if item_id == "axe":
			slot.disabled = state.amount("axe") == 0
		slot.tooltip_text = "%d · %s" % [index + 1, item["name"]]
		slot.custom_minimum_size = Vector2(58, 58)
		Style.button(slot, state.selected_item == item_id)
		slot.custom_minimum_size = Vector2(58, 58)
		slot.pressed.connect(func() -> void: item_selected.emit(item_id))
		row.add_child(slot)
