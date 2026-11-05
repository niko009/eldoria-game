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
var selected_recipe := ""
var selected_category := "Все"
var tile_grid: GridContainer
var detail: VBoxContainer

func _ready() -> void:
	add_theme_constant_override("separation", 5)
	if state != null:
		state.changed.connect(refresh)
	refresh()

func _choose(recipe_id: String) -> void:
	selected_recipe = recipe_id
	refresh()

func refresh() -> void:
	if state != null and recipe_order.is_empty():
		recipe_order = state.recipes_ready_first()
	if selected_recipe.is_empty() and not recipe_order.is_empty():
		selected_recipe = recipe_order[0]
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if state == null:
		return
	var heading := Style.label("ВЫБЕРИТЕ ПРЕДМЕТ", 12, Style.GOLD)
	add_child(heading)
	var categories := HBoxContainer.new()
	categories.name = "RecipeCategories"
	add_child(categories)
	for category in ["Все", "Оружие", "Броня", "Еда", "Расходники"]:
		var filter := Button.new()
		filter.text = category
		Style.button(filter, selected_category == category)
		filter.pressed.connect(func() -> void:
			selected_category = category
			refresh())
		categories.add_child(filter)
	tile_grid = GridContainer.new()
	tile_grid.name = "RecipeGrid"
	tile_grid.columns = 5
	tile_grid.add_theme_constant_override("h_separation", 6)
	tile_grid.add_theme_constant_override("v_separation", 5)
	add_child(tile_grid)
	for recipe_id in recipe_order:
		if not _category_matches(recipe_id):
			continue
		var recipe: Dictionary = State.RECIPES[recipe_id]
		var ready := craft_enabled and state.recipe_materials_ready(recipe_id)
		var tile := Button.new()
		tile.name = "RecipeCard_%s" % recipe_id
		tile.custom_minimum_size = Vector2(70, 64)
		tile.tooltip_text = str(recipe["name"])
		Style.button(tile, selected_recipe == recipe_id)
		tile.pressed.connect(_choose.bind(recipe_id))
		tile_grid.add_child(tile)
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tile.add_child(content)
		var icon: Control = ItemIcon.new()
		icon.custom_minimum_size = Vector2(37, 37)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.setup(recipe_id, state.amount(recipe_id) < state.recipe_limit(recipe_id), ready)
		content.add_child(icon)
		var mark := Style.label("●" if ready else "○", 11, Color("a9f5b0") if ready else Color("e89883"))
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(mark)
	if not _category_matches(selected_recipe):
		for recipe_id in recipe_order:
			if _category_matches(recipe_id):
				selected_recipe = recipe_id
				break
	var shell := PanelContainer.new()
	shell.name = "SelectedRecipe"
	shell.add_theme_stylebox_override("panel", Style.panel(Color("202a30", 0.93), Color("58615c"), 12))
	add_child(shell)
	detail = VBoxContainer.new()
	detail.name = "RecipeDetails"
	detail.add_theme_constant_override("separation", 5)
	shell.add_child(detail)
	var recipe: Dictionary = State.RECIPES[selected_recipe]
	var owned_full := state.amount(selected_recipe) >= state.recipe_limit(selected_recipe)
	var ready := craft_enabled and state.recipe_materials_ready(selected_recipe)
	var title := Style.label(str(recipe["name"]) + "  ×%d" % state.amount(selected_recipe), 16, Style.GOLD)
	detail.add_child(title)
	detail.add_child(Style.label(str(recipe["description"]), 12, Style.MUTED))
	var costs := HBoxContainer.new()
	costs.name = "IngredientIcons"
	detail.add_child(costs)
	for material in recipe["cost"]:
		var required: int = recipe["cost"][material]
		var owned: int = state.amount(material)
		var ingredient := HBoxContainer.new()
		ingredient.name = "Cost_%s" % material
		ingredient.tooltip_text = "%s: %d из %d" % [State.ITEMS[material]["name"],owned,required]
		costs.add_child(ingredient)
		var icon: Control = ItemIcon.new()
		icon.setup(material, owned >= required)
		icon.custom_minimum_size = Vector2(28, 28)
		ingredient.add_child(icon)
		ingredient.add_child(Style.label("%d/%d" % [owned,required], 12, Color("a9f5b0") if owned >= required else Color("e89883")))
	if not state.near_campfire:
		detail.add_child(Style.label("Для изготовления нужен костёр рядом", 12, Color("e89883")))
	var action := Button.new()
	action.name = "CraftSelected"
	action.text = "Лимит предметов" if owned_full else "Создать ×1"
	Style.button(action)
	action.disabled = not ready or not state.near_campfire or state.loading
	action.pressed.connect(func() -> void: craft_requested.emit(selected_recipe))
	detail.add_child(action)

func _category_matches(recipe_id: String) -> bool:
	match selected_category:
		"Оружие": return recipe_id in ["axe", "spear", "bow", "arrow", "wooden_staff"]
		"Броня": return recipe_id in ["shield", "leather_armor"]
		"Еда": return recipe_id == "grilled_meat"
		"Расходники": return recipe_id in ["bandage", "repair_kit", "mana_potion"]
		_: return true
