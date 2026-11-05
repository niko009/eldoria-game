extends SceneTree
const STATE = preload("res://ui/mock_game_ui_state.gd")
const WORKSHOP = preload("res://ui/CraftingPanel.tscn")
const SAVE = preload("res://world_save.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var state = STATE.new()
    state.inventory = {"wood":4,"stone":2,"herb":3,"wooden_staff":0}
    if not state.recipe_materials_ready("wooden_staff") or state.recipe_limit("wooden_staff") != 1:
        _fail("staff materials or unique equipment cap incorrect")
        return
    var workshop = WORKSHOP.instantiate()
    workshop.state = state
    root.add_child(workshop)
    await process_frame
    workshop._choose("wooden_staff")
    workshop.selected_category = "Доступно"
    workshop.refresh()
    if workshop.tile_grid.get_node_or_null("RecipeCard_wooden_staff") == null:
        _fail("ready staff missing from available recipe filter")
        return
    workshop.selected_category = "Все"
    workshop.refresh()
    var recipe_tile: Button = workshop.tile_grid.get_node("RecipeCard_wooden_staff")
    if recipe_tile.custom_minimum_size.x > 64 or recipe_tile.custom_minimum_size.y > 60:
        _fail("recipe card is too large for compact workshop")
        return
    if workshop.selected_recipe != "wooden_staff" or workshop.detail.get_node("CraftSelected").disabled:
        _fail("staff is not craftable from UI")
        return
    state.inventory["stone"] = 0
    state.changed.emit()
    workshop.selected_category = "Доступно"
    workshop.refresh()
    if workshop.tile_grid.get_node_or_null("RecipeCard_wooden_staff") != null:
        _fail("unaffordable staff remains in available recipe filter")
        return
    state.inventory["wood"] = 0
    state.inventory["herb"] = 0
    state.changed.emit()
    if workshop.get_node_or_null("EmptyRecipeCategory") == null or workshop.detail != null and workshop.detail.is_inside_tree():
        _fail("empty ready filter should show helpful empty state without stale recipe details")
        return
    state.inventory["wood"] = 4
    state.inventory["herb"] = 3
    state.inventory["stone"] = 2
    state.changed.emit()
    if workshop.tile_grid.get_node_or_null("RecipeCard_wooden_staff") == null:
        _fail("ready filter did not recover after materials returned")
        return
    state.inventory["stone"] = 0
    workshop.selected_category = "Все"
    workshop._choose("wooden_staff")
    var shortages: Label = workshop.detail.get_node_or_null("MissingIngredients")
    if shortages == null or not shortages.text.contains("Камень") or not shortages.text.contains("×2"):
        _fail("missing ingredients are not explained")
        return
    state.inventory["stone"] = 2
    state.inventory["wooden_staff"] = 1
    state.changed.emit()
    if not workshop.detail.get_node("CraftSelected").disabled:
        _fail("staff cap not reflected after inventory snapshot")
        return
    if workshop.detail.get_node_or_null("PostCraftHelp") == null:
        _fail("crafted staff has no next-step guidance")
        return
    if not SAVE._valid_equipment({"main_hand":"wooden_staff"},state.inventory,2):
        _fail("mage cannot equip owned staff")
        return
    if SAVE._valid_equipment({"main_hand":"wooden_staff"},state.inventory,0):
        _fail("non-mage can equip staff")
        return
    print("TASK073 STAFF UI PASS recipe, cap, selection, class restriction")
    quit(0)

func _fail(message: String) -> void:
    printerr("TASK073 STAFF UI FAIL: "+message)
    quit(1)