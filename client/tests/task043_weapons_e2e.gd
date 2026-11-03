extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	game.selected_avatar = 1 # Rogue: isolate shield item mitigation from Knight passive
	game._host()
	var id: int = game.own_id
	game.placed_buildings[991] = {"kind":"campfire","x":0.0,"z":0.0}
	game.players[id].position = Vector3(0,1,0)
	game.player_inventories[id] = {"wood":30,"stone":30,"herb":10,"axe":0,"spear":0,"bow":0,"shield":0,"arrow":0}
	for item in ["spear","bow","shield","arrow"]:
		if not game._craft_consumable_on_server(id,item):
			_fail("craft "+item)
			return
	if game._craft_consumable_on_server(id,"shield"):
		_fail("duplicate shield")
		return
	game.raid.deadline_ms = Time.get_ticks_msec()-1
	game._combat_server_tick(0.02)
	game.wolf_alive = true
	game.wolf_health = 60
	game.wolf_position = Vector3(4,1,0)
	for wolf_id in game.pack_wolves:
		game.pack_wolves[wolf_id]["alive"] = false
	if not game._equip_combat_on_server(id,"spear") or not game._attack_on_server(id) or game.wolf_health != 30:
		_fail("spear range/damage")
		return
	game.last_attack_at.erase(id)
	game.wolf_health = 60
	var aimed: Vector3 = (game.wolf_position + Vector3.UP*0.65 - (game.players[id].position + Vector3.UP*0.8)).normalized()
	if not game._equip_combat_on_server(id,"bow") or not game._attack_on_server(id,aimed) or game.wolf_health != 40 or int(game.player_inventories[id]["arrow"]) != 0:
		_fail("bow damage/arrow spending")
		return
	game.last_attack_at.erase(id)
	if game._attack_on_server(id,aimed):
		_fail("bow fired without arrow")
		return
	if not game._equip_combat_on_server(id,"shield"):
		_fail("shield equip")
		return
	game.player_health[id] = 100
	if not game._damage_player_on_server(id, 20) or int(game.player_health[id]) != 88:
		_fail("shield mitigation")
		return
	print("TASK043 WEAPONS PASS spear, bow, arrows, shield, server validation")
	quit(0)
func _fail(reason: String) -> void:
	printerr("TASK043 WEAPONS FAIL: "+reason)
	quit(1)
