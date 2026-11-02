extends VBoxContainer
class_name EldoriaCraftingPanel

signal craft_requested(recipe_id: String)

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
	var recipe: Dictionary = State.RECIPES["axe"]
	add_child(Style.label("РЕЦЕПТ", 14, Style.GOLD))
	add_child(Style.label("⚒  %s" % recipe["name"], 20))
	add_child(Style.label(recipe["description"], 14, Style.MUTED))
	for item_id in recipe["cost"]:
		var required: int = recipe["cost"][item_id]
		var owned := state.amount(item_id)
		add_child(Style.label("%s  %d / %d" % [State.ITEMS[item_id]["name"], owned, required], 15, Style.TEXT if owned >= required else Color("e89883")))
	var action := Button.new()
	action.text = "Создать · Preview"
	Style.button(action)
	action.disabled = not state.can_afford(recipe["cost"]) or state.loading
	action.pressed.connect(func() -> void: craft_requested.emit("axe"))
	add_child(action)
	if action.disabled:
		add_child(Style.label("Недостаточно ресурсов" if not state.loading else "Подождите…", 13, Style.MUTED))
