extends VBoxContainer
class_name EldoriaBuildingPanel

signal build_requested(building_id: String)

const Style = preload("res://ui/ui_style.gd")
const State = preload("res://ui/mock_game_ui_state.gd")
var state: MockGameUiState
var selected := "campfire"

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
	add_child(Style.label("ПОСТРОЙКИ", 14, Style.GOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for id in State.BUILDINGS:
		var button := Button.new()
		button.text = State.BUILDINGS[id]["name"]
		Style.button(button, selected == id)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select.bind(id))
		row.add_child(button)
	var entry: Dictionary = State.BUILDINGS[selected]
	add_child(Style.label(entry["description"], 16))
	for item_id in entry["cost"]:
		var required: int = entry["cost"][item_id]
		var owned := state.amount(item_id)
		add_child(Style.label("%s  %d / %d" % [State.ITEMS[item_id]["name"], owned, required], 15, Style.TEXT if owned >= required else Color("e89883")))
	var action := Button.new()
	action.text = "Разместить · Preview"
	Style.button(action)
	action.disabled = not state.can_afford(entry["cost"]) or state.loading
	action.pressed.connect(func() -> void: build_requested.emit(selected))
	add_child(action)
	if action.disabled:
		add_child(Style.label("Недостаточно ресурсов" if not state.loading else "Подождите…", 13, Style.MUTED))

func _select(id: String) -> void:
	selected = id
	refresh()
