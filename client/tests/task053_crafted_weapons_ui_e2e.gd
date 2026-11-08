extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	game.selected_avatar = 1 # Rogue: attack button always means a weapon strike.
	game.is_websocket_host = true
	game._host()
	game.set_physics_process(false)
	var id: int = game.own_id
	var ui = game.live_ui
	var world: Node3D = game.get_node("Eldoria_Forest")
	if id <= 0 or ui == null:
		_fail("live game or UI missing")
		return
	game.placed_buildings[9053] = {"kind":"campfire","x":0.0,"z":0.0}
	game.players[id].position = Vector3(0,world.height_at(0,0)+1,0)
	game.player_inventories[id] = game._empty_inventory()
	game.player_inventories[id]["wood"] = 30
	game.player_inventories[id]["stone"] = 30
	game.player_inventories[id]["herb"] = 10
	game.inventory_snapshot(game.player_inventories[id])
	ui.set_near_campfire(true)
	for weapon in ["spear","bow","shield","arrow"]:
		if ui.active_panel != "craft":
			ui._open("craft")
		ui._craft(weapon)
		if int(game.player_inventories[id].get(weapon,0)) != 1 or ui.state.amount(weapon) != 1:
			_fail("crafting UI did not reflect server inventory: "+weapon)
			return
	# Repeated ammunition crafting must keep the workshop open and the
	# arrow card at the same index after each inventory snapshot.
	var arrow_card: Node = ui.current_panel.tile_grid.get_node("RecipeCard_arrow")
	var arrow_index := arrow_card.get_index()
	for expected in [2,3,4]:
		ui._craft("arrow")
		if ui.active_panel != "craft" or ui.state.amount("arrow") != expected:
			_fail("repeat crafting arrows closed workshop or failed: "+str(expected))
			return
		if ui.current_panel.tile_grid.get_node("RecipeCard_arrow").get_index() != arrow_index:
			_fail("arrow card jumps after crafting")
			return
	# The user's original failure path: the workshop's 'Equip' button sent
	# an action that main.gd previously ignored entirely.
	if ui.active_panel != "craft":
		ui._open("craft")
	ui.current_panel._choose("bow")
	var equip_bow: Button = ui.current_panel.detail.get_node_or_null("EquipCrafted")
	if equip_bow == null or equip_bow.disabled:
		_fail("workshop bow equip action not clickable")
		return
	equip_bow.pressed.emit()
	if str(game.equipped_combat.get(id,"")) != "bow" or ui.active_panel != "":
		_fail("workshop Equip did not route to server")
		return
	# The hotbar is the primary Android and Windows equipment control.
	for weapon in ["spear","bow","shield"]:
		# A bow occupies both hands; the new offhand shield deliberately cannot
		# be equipped until the bow is stowed. Staff + shield remains allowed.
		if weapon == "shield":
			game._try_equip_combat("unarmed")
		if ui.hud.hotbar.slot_buttons[weapon].disabled:
			_fail("crafted weapon hotbar still disabled: "+weapon)
			return
		ui.hud.hotbar.slot_buttons[weapon].pressed.emit()
		var equipped_ok: bool = str(game.equipped_offhand.get(id,"")) == "shield" and ui.shield_equipped if weapon == "shield" else str(game.equipped_combat.get(id,"")) == weapon and ui.combat_equipment == weapon and ui.state.selected_item == weapon
		if not equipped_ok:
			_fail("server, live UI or hotbar equipment selection mismatch: "+weapon+" main="+str(game.equipped_combat.get(id,"?"))+" off="+str(game.equipped_offhand.get(id,"?"))+" UI="+str(ui.shield_equipped)+" selected="+str(ui.state.selected_item))
			return
	# Inventory alternative also equips weapon, no crafting menu necessary.
	ui._open("inventory")
	var inventory = ui.current_panel
	var bow_button: Button = inventory.get_node_or_null("ItemGrid/ItemSlot_bow")
	if bow_button == null or bow_button.disabled:
		_fail("owned bow not selectable in inventory")
		return
	bow_button.pressed.emit()
	if str(game.equipped_combat.get(id,"")) != "bow":
		_fail("inventory bow didn't equip on authoritative server")
		return
	ui._close()
	game.wolf_position = Vector3(4,world.height_at(4,0)+0.1,0)
	game.wolf_health = 60
	game.wolf_alive = true
	game.pack_wolves.clear()
	var from: Vector3 = game.players[id].position + Vector3.UP*0.8
	var aim: Vector3 = (game.wolf_position + Vector3.UP*0.65-from).normalized()
	game.input_driver.yaw = atan2(-aim.x,-aim.z)
	game.input_driver.pitch = atan2(aim.y,Vector2(aim.x,aim.z).length())
	game._try_attack()
	if game.wolf_health != 40 or int(game.player_inventories[id]["arrow"]) != 3:
		_fail("bow did not shoot after hotbar/inventory equip")
		return
	ui.hud.hotbar.slot_buttons["spear"].pressed.emit()
	game.last_attack_at.erase(id)
	game._try_attack()
	if game.wolf_health != 10:
		_fail("spear did not strike after hotbar equip")
		return
	print("TASK053 CRAFTED WEAPONS UI PASS real craft, hotbar/inventory equip, server ACK, bow shot and spear attack")
	quit(0)
func _fail(reason: String) -> void:
	printerr("TASK053 CRAFTED WEAPONS UI FAIL: "+reason)
	quit(1)
