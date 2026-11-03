extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	game._host()
	var id: int = game.own_id
	game.placed_buildings[990] = {"kind":"campfire","x":0.0,"z":0.0}
	game.players[id].position = Vector3(0,1,0)
	game.player_inventories[id] = {"wood":10,"stone":8,"herb":5,"axe":0,"bandage":0,"repair_kit":0}
	if not game._craft_consumable_on_server(id,"bandage") or not game._craft_consumable_on_server(id,"repair_kit"):
		_fail("craft recipe rejected")
		return
	var inv: Dictionary = game.player_inventories[id]
	if inv.get("bandage") != 1 or inv.get("repair_kit") != 1 or inv.get("wood") != 6 or inv.get("stone") != 6 or inv.get("herb") != 3:
		_fail("recipe ingredients incorrect: " + str(inv))
		return
	game.player_health[id] = 50
	if not game._use_consumable_on_server(id,"bandage") or game.player_health[id] != 90 or int(game.player_inventories[id]["bandage"]) != 0:
		_fail("bandage heal failed")
		return
	game.raid.deadline_ms = Time.get_ticks_msec()-1
	game._combat_server_tick(0.02)
	game.camp_hp = 50
	if not game._use_consumable_on_server(id,"repair_kit") or game.camp_hp != 110 or int(game.player_inventories[id]["repair_kit"]) != 0:
		_fail("repair kit failed")
		return
	if game._use_consumable_on_server(id,"repair_kit") or game._craft_consumable_on_server(id,"unsupported"):
		_fail("invalid item accepted")
		return
	print("TASK042 CRAFT PASS server costs, bandage heal, repair kit, duplicate protection")
	quit(0)
func _fail(reason: String) -> void:
	printerr("TASK042 CRAFT FAIL: "+reason)
	quit(1)
