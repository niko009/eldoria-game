extends SceneTree
const GAME := preload("res://Main.tscn")
const ITEMS := preload("res://ui/mock_game_ui_state.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(800,360)
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	game.selected_avatar = 1
	game._host()
	game.set_physics_process(false)
	var id: int = game.own_id
	var ui = game.live_ui
	ui.size = Vector2(800,360)
	ui._layout()
	var inventory: Dictionary = game._empty_inventory()
	for item in ITEMS.ITEMS:
		inventory[item] = 1
	inventory["wood"] = 30
	inventory["stone"] = 30
	inventory["herb"] = 30
	inventory["arrow"] = 5
	game.player_inventories[id] = inventory
	game.inventory_snapshot(inventory)
	ui._open("inventory")
	await process_frame
	await process_frame
	var panel = ui.current_panel
	var grid: GridContainer = panel.get_node("ItemGrid")
	if grid.get_child_count() != ITEMS.ITEMS.size() or grid.columns != 4:
		_fail("inventory grid missing items or wrong columns")
		return
	for item in ITEMS.ITEMS:
		var slot: Button = grid.get_node("ItemSlot_"+item)
		if slot.text != "" or slot.get_node_or_null("Icon_"+item) == null:
			_fail("missing icon or unrequested text in inventory: "+item)
			return
		if slot.get_node("Quantity").text != "×%d" % inventory[item]:
			_fail("quantity not visible: "+item)
			return
	if grid.get_combined_minimum_size().x > ui.contents.size.x+1:
		_fail("inventory grid exceeds Android landscape width")
		return
	grid.get_node("ItemSlot_wood").pressed.emit()
	if not panel.get_node("ItemDetail").text.contains("Древесина"):
		_fail("touch on resource icon did not explain item")
		return
	grid.get_node("ItemSlot_spear").pressed.emit()
	if game.equipped_combat[id] != "spear" or ui.hud.action_controls["attack"].get_node("Caption").text != "УКОЛ":
		_fail("spear cannot be selected via inventory icon")
		return
	if game.players[id].combat_visual.get_node_or_null("SteelSpearPoint") == null:
		_fail("recognizable spear point missing from animated hero")
		return
	ui._close()
	ui._open("craft")
	await process_frame
	for recipe_id in ITEMS.RECIPES:
		var card = ui.current_panel.get_node("RecipeCard_"+recipe_id).get_node("Recipe_"+recipe_id)
		if card.find_children("ResultIcon","Control",true,false).is_empty():
			_fail("recipe product icon missing: "+recipe_id)
			return
		var ingredients: HBoxContainer = card.get_node("IngredientIcons")
		if ingredients.get_child_count() != ITEMS.RECIPES[recipe_id]["cost"].size():
			_fail("recipe cost missing icon count: "+recipe_id)
			return
		for ing in ingredients.get_children():
			if ing.get_child(0).get_script().resource_path != "res://ui/item_icon.gd":
				_fail("cost uses word instead of item icon: "+recipe_id)
				return
	ui._close()
	# The spear no longer auto-hits targets behind the player.
	var world: Node3D = game.get_node("Eldoria_Forest")
	game.players[id].position = Vector3(0,world.height_at(0,0)+1,0)
	game.wolf_alive = true
	game.wolf_health = 60
	game.wolf_position = Vector3(4,world.height_at(4,0)+0.1,0)
	game.pack_wolves.clear()
	if game._attack_on_server(id,Vector3.LEFT) or game.wolf_health != 60:
		_fail("spear hit a wolf behind the character")
		return
	if not ui.notice.text.contains("перед вами"):
		_fail("missing understandable spear miss feedback")
		return
	if not game._attack_on_server(id,Vector3.RIGHT) or game.wolf_health != 30:
		_fail("spear failed aimed frontal hit")
		return
	if not ui.notice.text.contains("попадание"):
		_fail("spear hit feedback missing")
		return
	if not game._equip_combat_on_server(id,"bow"):
		_fail("bow equip rejected")
		return
	if ui.hud.action_controls["attack"].get_node("Caption").text != "ВЫСТРЕЛ":
		_fail("bow button not labeled ВЫСТРЕЛ")
		return
	if game.players[id].combat_visual.get_node_or_null("BowString") == null:
		_fail("bow remains an unrecognizable cylinder")
		return
	if not ui.bow_aim_hint.visible or not ui.combat_aim_help.visible:
		_fail("bow reticle/instructions missing")
		return
	ui.set_combat_reticle(Vector2(300,210))
	if absf((ui.bow_aim_hint.position+ui.bow_aim_hint.size*0.5).x-300) > 2:
		_fail("bow reticle does not follow the true projected aim point")
		return
	game.player_inventories[id]["arrow"] = 0
	game.inventory_snapshot(game.player_inventories[id])
	game.last_attack_at.erase(id)
	if game._attack_on_server(id,Vector3.RIGHT) or not ui.notice.text.contains("Нет стрел"):
		_fail("bow attack without ammo has no useful feedback")
		return
	print("TASK054 COMBAT ICONS PASS all 10 inventory icons/counts, 7 graphical recipes, spear front arc, real weapon models, bow aim/ammo feedback")
	quit(0)

func _fail(message: String) -> void:
	printerr("TASK054 COMBAT ICONS FAIL: "+message)
	quit(1)
