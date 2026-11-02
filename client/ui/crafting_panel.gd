extends VBoxContainer
class_name EldoriaCraftingPanel

signal craft_requested(recipe_id: String)

const Style = preload("res://ui/ui_style.gd")
const State = preload("res://ui/mock_game_ui_state.gd")
var state: MockGameUiState
var craft_enabled := true

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
	action.text = "Создать" if craft_enabled else "Пока недоступно"
	Style.button(action)
	action.disabled = not craft_enabled or not state.near_campfire or state.amount("axe") > 0 or not state.can_afford(recipe["cost"]) or state.loading
	action.pressed.connect(func() -> void: craft_requested.emit("axe"))
	add_child(action)
	if action.disabled:
		var reason := ""
		if not craft_enabled:
			reason = "Пока недоступно"
		elif state.amount("axe") > 0:
			reason = "Каменный топор уже изготовлен"
		elif not state.near_campfire:
			reason = "Подойдите к костру (не дальше 4 м)"
		elif state.loading:
			reason = "Подождите…"
		else:
			reason = "Недостаточно ресурсов"
		add_child(Style.label(reason, 13, Style.MUTED))
