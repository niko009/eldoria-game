extends VBoxContainer
class_name EldoriaCraftingPanel

signal craft_requested(recipe_id: String)
signal use_requested(recipe_id: String)
signal equip_requested(recipe_id: String)

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
	var heading := Style.label("РЕЦЕПТЫ   ● доступно   ○ пока нельзя", 12, Style.GOLD)
	add_child(heading)
	var categories := HBoxContainer.new()
	categories.name = "RecipeCategories"
	add_child(categories)
	for category in ["Все", "Доступно", "Оружие", "Броня", "Еда", "Расходники"]:
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
		tile.custom_minimum_size = Vector2(62, 58)
		tile.tooltip_text = str(recipe["name"]) + " · " + ("ГОТОВО" if ready and state.near_campfire else "ЛИМИТ" if state.amount(recipe_id) >= state.recipe_limit(recipe_id) else "НЕ ХВАТАЕТ РЕСУРСОВ" if not state.recipe_materials_ready(recipe_id) else "НУЖЕН КОСТЁР")
		Style.button(tile, selected_recipe == recipe_id)
		tile.add_theme_stylebox_override("normal", Style.panel(Color("243a31",0.90) if ready and state.near_campfire else Color("222b30",0.86), Color("81bf87",0.85) if ready and state.near_campfire else Color("59605e",0.43), 10))
		tile.pressed.connect(_choose.bind(recipe_id))
		tile_grid.add_child(tile)
		var content := VBoxContainer.new()
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tile.add_child(content)
		var icon: Control = ItemIcon.new()
		icon.custom_minimum_size = Vector2(32, 32)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.setup(recipe_id, state.amount(recipe_id) < state.recipe_limit(recipe_id), ready)
		content.add_child(icon)
		var mark := Style.label("●" if ready and state.near_campfire else "○", 10, Color("a9f5b0") if ready and state.near_campfire else Color("b1a6a0"))
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(mark)
	if not _category_matches(selected_recipe):
		selected_recipe = ""
		for recipe_id in recipe_order:
			if _category_matches(recipe_id):
				selected_recipe = recipe_id
				break
	if selected_recipe.is_empty():
		var empty := Style.label("Нет доступных рецептов. Соберите ресурсы или подойдите к костру.", 12, Style.MUTED)
		empty.name = "EmptyRecipeCategory"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(empty)
		return
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
	var title := Style.label(str(recipe["name"]) + "  ×%d" % state.amount(selected_recipe), 15, Style.GOLD)
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
	var shortages: Array[String] = []
	for material in recipe["cost"]:
		var missing: int = maxi(0, int(recipe["cost"][material]) - state.amount(material))
		if missing > 0:
			shortages.append("%s ×%d" % [str(State.ITEMS[material]["name"]), missing])
	if not shortages.is_empty():
		var missing_label := Style.label("Собрать: " + ", ".join(shortages), 12, Color("e89883"))
		missing_label.name = "MissingIngredients"
		missing_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail.add_child(missing_label)
	if not state.near_campfire:
		detail.add_child(Style.label("Для изготовления нужен костёр рядом", 12, Color("e89883")))
	var action := Button.new()
	action.name = "CraftSelected"
	action.text = "Лимит предметов" if owned_full else "Создать: %s" % str(recipe["name"])
	Style.button(action)
	action.disabled = not ready or not state.near_campfire or state.loading
	action.pressed.connect(func() -> void: craft_requested.emit(selected_recipe))
	detail.add_child(action)
	if state.amount(selected_recipe) > 0 and selected_recipe in ["axe", "spear", "bow", "shield", "wooden_staff", "leather_armor"]:
		var hint := Style.label("Создано · Наденьте в Рюкзаке → Оружие / Экипировка", 12, Style.GOLD)
		hint.name = "PostCraftHelp"
		# The action below is the instruction; avoid duplicating a full line of text.
		hint.visible = false
		detail.add_child(hint)
		var equip := Button.new()
		equip.name = "EquipCrafted"
		equip.text = "Надеть: %s" % str(recipe["name"])
		equip.disabled = state.loading or (selected_recipe == "wooden_staff" and state.selected_avatar != "mage")
		Style.button(equip)
		equip.pressed.connect(func() -> void: equip_requested.emit(selected_recipe))
		detail.add_child(equip)
	elif state.amount(selected_recipe) > 0 and selected_recipe in ["bandage", "mana_potion", "grilled_meat"]:
		var hint := Style.label("Создано · Используйте кнопку предмета на игровом экране", 12, Style.GOLD)
		hint.name = "PostCraftHelp"
		hint.visible = false
		detail.add_child(hint)
		var use := Button.new()
		use.name = "UseCrafted"
		use.text = "Использовать: %s" % str(recipe["name"])
		use.disabled = state.loading or (selected_recipe == "mana_potion" and state.selected_avatar != "mage")
		Style.button(use)
		use.pressed.connect(func() -> void: use_requested.emit(selected_recipe))
		detail.add_child(use)

func _category_matches(recipe_id: String) -> bool:
	match selected_category:
		"Доступно": return craft_enabled and state.near_campfire and state.recipe_materials_ready(recipe_id)
		"Оружие": return recipe_id in ["axe", "spear", "bow", "arrow", "wooden_staff"]
		"Броня": return recipe_id in ["shield", "leather_armor"]
		"Еда": return recipe_id == "grilled_meat"
		"Расходники": return recipe_id in ["bandage", "repair_kit", "mana_potion"]
		_: return true
