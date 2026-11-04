extends SceneTree
const GAME := preload("res://Main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node3D = GAME.instantiate()
	game.selected_avatar = 1 # Deterministic Rogue baseline; no Knight resistance.
	root.add_child(game)
	await process_frame
	game._host()
	game.set_physics_process(false)
	var id: int = game.own_id
	game.player_choices[id] = 1 # Force Rogue; persisted profile can select Knight.
	var world: Node3D = game.get_node("Eldoria_Forest")
	var pos := Vector3(0,world.height_at(0,0)+1,0)
	game.players[id].position = pos
	game.player_inventories[id] = game._empty_inventory()
	var friend := 992
	game._spawn(friend,pos+Vector3(0,0,1),0)
	game.player_health[friend] = 100
	game.player_inventories[friend] = game._empty_inventory()
	for mob_id in [1,2,3,4,7]:
		var animal: Dictionary = game.passive_creatures[mob_id]
		animal["position"] = pos
		if not game._damage_passive_on_server(id,mob_id,120,Time.get_ticks_msec()):
			_fail("hunt kill rejected: "+str(mob_id))
			return
	if game.shared_hunt_kills != 0:
		_fail("co-op quest did not complete and restart")
		return
	if int(game.player_inventories[friend].get("hide",0)) != 2 or int(game.player_inventories[friend].get("bone",0)) != 1:
		_fail("second player did not receive cooperative reward")
		return
	if int(game.player_inventories[id].get("meat",0)) < 5:
		_fail("animal loot absent")
		return
	game.players[id].position = pos
	game.player_inventories[id] = game._empty_inventory()
	game.placed_buildings[998] = {"kind":"campfire","x":0.0,"z":0.0}
	game.player_inventories[id]["hide"] = 3
	game.player_inventories[id]["bone"] = 1
	if not game._craft_consumable_on_server(id,"leather_armor"):
		_fail("leather armor craft rejected")
		return
	if int(game.player_inventories[id]["leather_armor"]) != 1 or game._craft_consumable_on_server(id,"leather_armor"):
		_fail("leather armor duplicate allowed")
		return
	game.wolf_alive = true
	game.player_health[id] = 100
	game._damage_player_on_server(id,20)
	if int(game.player_health[id]) != 83:
		_fail("leather armor did not reduce 20 damage to 17")
		return
	var rare: Dictionary = game.passive_creatures[15]
	if rare["species"] != "rare_deer" or int(rare["hp"]) != 95:
		_fail("rare deer not spawned")
		return
	if game.passive_actors[15].get_node_or_null("RareWildlifeLabel") == null:
		_fail("rare deer missing visual identification")
		return
	var before_hide := int(game.player_inventories[id].get("hide",0))
	var before_bone := int(game.player_inventories[id].get("bone",0))
	var before_meat := int(game.player_inventories[id].get("meat",0))
	rare["position"] = pos
	if not game._damage_passive_on_server(id,15,120,Time.get_ticks_msec()):
		_fail("rare deer kill rejected")
		return
	if int(game.player_inventories[id].get("hide",0)) != before_hide+3 or int(game.player_inventories[id].get("bone",0)) != before_bone+3 or int(game.player_inventories[id].get("meat",0)) != before_meat+3:
		_fail("rare loot quantities incorrect")
		return
	print("TASK066 HUNT COOP PASS loot, shared quest reward, armor craft and mitigation")
	quit(0)

func _fail(message: String) -> void:
	printerr("TASK066 HUNT COOP FAIL: "+message)
	quit(1)
