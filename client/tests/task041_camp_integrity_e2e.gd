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
	if id <= 0:
		_fail("host not ready")
		return
	game.placed_buildings[777] = {"kind":"campfire","x":0.0,"z":0.0}
	game.player_inventories[id] = {"wood":5,"stone":3,"herb":0,"axe":0}
	game.raid.deadline_ms = Time.get_ticks_msec()-1
	game._combat_server_tick(0.02)
	if game.camp_hp != 120 or game.camp_target_id != 777:
		_fail("camp target not initialized")
		return
	var now := Time.get_ticks_msec()
	if not game._damage_camp(45,now,1) or game.camp_hp != 75:
		_fail("camp damage failed")
		return
	if game._damage_camp(45,now,1):
		_fail("attack cooldown bypassed")
		return
	game.players[id].position = Vector3(0,1,0)
	if not game._repair_camp_on_server(id) or game.camp_hp != 105:
		_fail("repair failed")
		return
	if int(game.player_inventories[id]["wood"]) != 3 or int(game.player_inventories[id]["stone"]) != 2:
		_fail("repair payment wrong")
		return
	if game._repair_camp_on_server(id):
		_fail("repair cooldown bypassed")
		return
	if not game._damage_camp(105,now+1801,2) or game.raid.phase != "intermission":
		_fail("camp destroyed did not end night")
		return
	if game._repair_camp_on_server(id):
		_fail("repair possible after defeat")
		return
	print("TASK041 CAMP INTEGRITY PASS damage, cooldown, repair payment, camp loss")
	quit(0)
func _fail(reason: String) -> void:
	printerr("TASK041 CAMP INTEGRITY FAIL: " + reason)
	quit(1)
