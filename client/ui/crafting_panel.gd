extends VBoxContainer
class_name EldoriaCraftingPanel

signal craft_requested(recipe_id: String)
signal use_requested(recipe_id: String)

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
		remove_child(child)
		child.queue_free()
	if state == null:
		return
	for recipe_id in state.recipes_ready_first():
		var recipe: Dictionary = State.RECIPES[recipe_id]
		var owned_full := state.amount(recipe_id) >= state.recipe_limit(recipe_id)
		var ready := craft_enabled and state.recipe_materials_ready(recipe_id)
		var card := VBoxContainer.new()
		card.name = "Recipe_%s" % recipe_id
		card.add_theme_constant_override("separation", 5)
		var card_shell := PanelContainer.new()
		card_shell.name = "RecipeCard_%s" % recipe_id
		card_shell.add_theme_stylebox_override("panel", Style.panel(Color("224638", 0.94) if ready else Color("202a30", 0.75), Color("93df99") if ready else Color("58615c"), 14))
		card_shell.add_child(card)
		add_child(card_shell)
		var title := "● МОЖНО СОЗДАТЬ · " if ready else "РЕЦЕПТ · "
		card.add_child(Style.label(title + str(recipe["name"]), 19, Color("a9f5b0") if ready else Style.MUTED))
		card.add_child(Style.label(recipe["description"], 13, Style.MUTED))
		for material in recipe["cost"]:
			var required: int = recipe["cost"][material]
			var owned := state.amount(material)
			card.add_child(Style.label("%s  %d / %d" % [State.ITEMS[material]["name"], owned, required], 14, Color("a9f5b0") if owned >= required else Color("e89883")))
		var action := Button.new()
		action.text = "Создать" if not owned_full else "Достигнут лимит"
		Style.button(action)
		action.disabled = not ready or not state.near_campfire or state.loading
		action.pressed.connect(func() -> void: craft_requested.emit(recipe_id))
		card.add_child(action)
		if recipe_id != "axe" and recipe_id != "arrow":
			var use_button := Button.new()
			use_button.text = ("Экипировать" if ["spear","bow","shield"].has(recipe_id) else "Использовать") + " · %d" % state.amount(recipe_id)
			Style.button(use_button)
			use_button.disabled = state.amount(recipe_id) <= 0 or state.loading
			use_button.pressed.connect(func() -> void: use_requested.emit(recipe_id))
			card.add_child(use_button)
