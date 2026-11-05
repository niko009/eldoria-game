extends SceneTree
const GAME := preload("res://Main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node3D = GAME.instantiate()
	game.selected_avatar = 1
	root.add_child(game)
	await process_frame
	game._host()
	game.set_physics_process(false)
	var id: int = game.own_id
	if id <= 0:
		_fail("no host player")
		return
	game.player_choices[id] = 1
	var world: Node3D = game.get_node("Eldoria_Forest")
	var at := Vector3(0,world.height_at(0,0)+1,0)
	game.players[id].position = at
	game.player_inventories[id] = game._empty_inventory()
	game.player_inventories[id]["meat"] = 2
	game.player_inventories[id]["herb"] = 2
	game.placed_buildings[990] = {"kind":"campfire","x":0.0,"z":0.0}
	if not game._craft_consumable_on_server(id,"grilled_meat"):
		_fail("food cooking failed")
		return
	if game.player_inventories[id]["meat"] != 1 or game.player_inventories[id]["herb"] != 1 or game.player_inventories[id]["grilled_meat"] != 1:
		_fail("cooking ingredients or recipe output mismatch")
		return
	game.player_health[id] = 45
	if not game._use_consumable_on_server(id,"grilled_meat") or game.player_health[id] != 70:
		_fail("food did not heal 25")
		return
	if int(game.player_inventories[id]["grilled_meat"]) != 0 or not game.food_regen_until.has(id):
		_fail("food not consumed or no regeneration buff")
		return
	game._combat_server_tick(1.1)
	if game.player_health[id] != 72:
		_fail("food healing-over-time incorrect: "+str(game.player_health[id]))
		return
	if game._use_consumable_on_server(id,"leather_armor"):
		_fail("equipment use bypassed consumable allowlist")
		return
	var friend := 992
	game._spawn(friend,at+Vector3(0,0,1),1)
	game.player_health[friend] = 100
	game.player_inventories[friend] = game._empty_inventory()
	for n in 5:
		game._record_team_hunt(id,at)
	var alpha: Dictionary = game.passive_creatures[game.ALPHA_WOLF_ID]
	if not alpha["alive"] or int(alpha["hp"]) != 180:
		_fail("co-op hunting did not summon a 180 HP wolf alpha")
		return
	if not game.live_ui.hud.practice_label.text.contains("ВОЖАК"):
		_fail("boss objective not visible in HUD")
		return
	var boss_actor: Node3D = game.passive_actors[game.ALPHA_WOLF_ID]
	if boss_actor.get_node_or_null("AlphaWolfTitle") == null or boss_actor.max_health != 180:
		_fail("boss visual or health bar missing")
		return
	alpha["position"] = at+Vector3(1,0,0)
	game.alpha_last_bite = Time.get_ticks_msec()-2500
	game._tick_alpha_wolf(0.05,Time.get_ticks_msec())
	if game.player_health[id] != 54:
		_fail("boss did not bite for 18 HP: "+str(game.player_health[id]))
		return
	var before_friend_hide := int(game.player_inventories[friend]["hide"])
	for n in 3:
		if not game._damage_passive_on_server(id,game.ALPHA_WOLF_ID,60,Time.get_ticks_msec()):
			_fail("boss damage refused")
			return
	if alpha["alive"] or game.alpha_available_at <= Time.get_ticks_msec():
		_fail("boss death or cooldown incorrect")
		return
	if int(game.player_inventories[friend]["hide"]) != before_friend_hide+4 or int(game.player_inventories[friend]["bone"]) != 4 or int(game.player_inventories[friend]["grilled_meat"]) != 2:
		_fail("friend did not receive boss trophy")
		return
	if game._damage_passive_on_server(id,game.ALPHA_WOLF_ID,100,Time.get_ticks_msec()):
		_fail("dead boss awarded a duplicate trophy")
		return
	game._summon_alpha_wolf(id,at)
	if alpha["alive"]:
		_fail("boss spawned during cooldown")
		return
	game._tick_passive_creatures(0.1,game.alpha_available_at+1000)
	if alpha["alive"]:
		_fail("generic mob respawn bypassed boss cooldown")
		return
	if game.live_ui.hud.practice_label.text.contains("ВОЖАК"):
		_fail("boss HUD not cleared after victory")
		return
	game.player_health[id] = 60
	game.live_ui._open("craft")
	await process_frame
	var recipe: Node = game.live_ui.current_panel.get_node("RecipeCard_grilled_meat")
	var meal_button: Button = null
	for button in recipe.find_children("*","Button",true,false):
		if button.text.begins_with("Использовать"):
			meal_button = button
	if meal_button == null or meal_button.disabled:
		_fail("cooked food cannot be used from crafting menu")
		return
	meal_button.pressed.emit()
	if game.player_health[id] != 85 or int(game.player_inventories[id]["grilled_meat"]) != 1:
		_fail("crafting UI did not consume a cooked meal")
		return
	print("TASK067 FOOD ALPHA PASS cooking, healing, regen, co-op summon, bite, trophy and cooldown")
	game.queue_free()
	await process_frame
	quit(0)

func _fail(why: String) -> void:
	printerr("TASK067 FOOD ALPHA FAIL: "+why)
	quit(1)
