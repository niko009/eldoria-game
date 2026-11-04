extends VBoxContainer
class_name EldoriaCraftingPanel

signal craft_requested(recipe_id: String)
signal use_requested(recipe_id: String)

const Style = preload("res://ui/ui_style.gd")
const State = preload("res://ui/mock_game_ui_state.gd")
const ItemIcon = preload("res://ui/item_icon.gd")
var state: MockGameUiState
var craft_enabled := true
var recipe_order: Array[String] = []

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	if state != null:
		state.changed.connect(refresh)
	refresh()

func refresh() -> void:
	# Sorting after every inventory snapshot made the selected recipe jump
	# elsewhere; preserve its position for the lifetime of this workshop.
	if state != null and recipe_order.is_empty():
		recipe_order = state.recipes_ready_first()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if state == null:
		return
	for recipe_id in recipe_order:
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
		card.tooltip_text = "%s\n%s" % [recipe["name"],recipe["description"]]
		# Visually lead with the crafted-item artwork, not prose recipes.
		var title := Style.label("● ГОТОВО" if ready else "○ НУЖНЫ РЕСУРСЫ",11,
			Color("a9f5b0") if ready else Style.MUTED)
		title.name = "RecipeStatus"
		card.add_child(title)
		var item_row := HBoxContainer.new()
		item_row.add_theme_constant_override("separation",9)
		card.add_child(item_row)
		var item_icon: Control = ItemIcon.new()
		item_icon.name = "ResultIcon"
		item_icon.custom_minimum_size = Vector2(52,52)
		item_icon.setup(recipe_id,not owned_full,ready)
		item_row.add_child(item_icon)
		var item_title := VBoxContainer.new()
		item_title.add_theme_constant_override("separation",2)
		item_row.add_child(item_title)
		item_title.add_child(Style.label(str(recipe["name"]),16,Style.GOLD))
		item_title.add_child(Style.label("В наличии ×%d" % state.amount(recipe_id),12,Style.MUTED))
		var cost_row := HBoxContainer.new()
		cost_row.name = "IngredientIcons"
		cost_row.add_theme_constant_override("separation",10)
		card.add_child(cost_row)
		for material in recipe["cost"]:
			var required: int = recipe["cost"][material]
			var owned: int = state.amount(material)
			var ingredient := HBoxContainer.new()
			ingredient.name = "Cost_%s" % material
			ingredient.tooltip_text = "%s: %d из %d" % [State.ITEMS[material]["name"],owned,required]
			ingredient.add_theme_constant_override("separation",1)
			var ingredient_icon: Control = ItemIcon.new()
			ingredient_icon.setup(material,owned >= required)
			ingredient_icon.custom_minimum_size = Vector2(35,35)
			ingredient.add_child(ingredient_icon)
			ingredient.add_child(Style.label("%d/%d" % [owned,required],14,
				Color("a9f5b0") if owned >= required else Color("e89883")))
			cost_row.add_child(ingredient)
		var action := Button.new()
		action.text = ("Создать ещё ×1" if recipe_id == "arrow" else "Создать") if not owned_full else "Достигнут лимит"
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
