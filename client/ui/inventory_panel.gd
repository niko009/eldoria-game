extends VBoxContainer
class_name EldoriaInventoryPanel

signal item_selected(item_id: String)

const Style = preload("res://ui/ui_style.gd")
const State = preload("res://ui/mock_game_ui_state.gd")
var state: MockGameUiState

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	if state != null:
		state.changed.connect(refresh)
	refresh()

func refresh() -> void:
	for child in get_children():
		child.queue_free()
	if state == null:
		return
	add_child(Style.label("ПРЕДМЕТЫ", 14, Style.GOLD))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	var any_item := false
	for item_id in State.ITEMS:
		var data: Dictionary = State.ITEMS[item_id]
		var count := state.amount(item_id)
		any_item = any_item or count > 0
		var slot := Button.new()
		slot.text = "%s  %s\n%d шт." % [data["symbol"], data["name"], count]
		slot.tooltip_text = data["name"]
		Style.button(slot, state.selected_item == item_id)
		slot.custom_minimum_size = Vector2(180, 72)
		slot.pressed.connect(func() -> void: item_selected.emit(item_id))
		grid.add_child(slot)
	if not any_item:
		add_child(Style.label("Рюкзак пуст. Предметы появятся здесь.", 14, Style.MUTED))
	add_child(Style.label("Выбрано: %s" % State.ITEMS[state.selected_item]["name"], 14, Style.MUTED))
