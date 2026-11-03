extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	for i in 520:
		await process_frame
		if game.players.size() == 2:
			break
	if game.players.size() != 2:
		_fail("missing 2 players")
		return
	game.set_physics_process(false)
	var defender := -1
	var archer := -1
	for id in game.players:
		if game.player_choices[id] == 2:
			defender = int(id)
		else:
			archer = int(id)
	if defender < 0 or archer < 0:
		_fail("roles missing")
		return
	var world: Node3D = game.get_node("Eldoria_Forest")
	var at := Vector3(0,world.height_at(0,0)+1,0)
	game.players[defender].position = at+Vector3(0,0,7)
	game.players[archer].position = at+Vector3(0,0,2)
	game.correct_own_position.rpc_id(defender,game.players[defender].position)
	game.correct_own_position.rpc_id(archer,game.players[archer].position)
	game.player_inventories[defender] = game._empty_inventory()
	game.player_inventories[defender]["shield"] = 1
	game.inventory_snapshot.rpc_id(defender,game.player_inventories[defender])
	if not game._equip_combat_on_server(defender,"shield"):
		_fail("server shield equip failed")
		return
	game.wolf_alive = true
	game.wolf_position = at
	game.wolf_health = 60
	game.pack_wolves.clear()
	game.wolf_snapshot.rpc(game.wolf_position,60,true,Vector3.ZERO)
	if game._choose_wolf_target(at,Time.get_ticks_msec()) != archer:
		_fail("archer should be preferred by proximity")
		return
	for i in 450:
		await process_frame
		if int(game.shield_taunt_until.get(defender,0)) > Time.get_ticks_msec():
			break
	if int(game.shield_taunt_until.get(defender,0)) <= Time.get_ticks_msec() or game._choose_wolf_target(at,Time.get_ticks_msec()) != defender:
		_fail("remote shield taunt did not redirect server's wolf target")
		return
	if game.shield_taunt_until.has(archer) or game.player_health[archer] != 100:
		_fail("archer state changed by defender taunt")
		return
	await create_timer(0.7).timeout
	print("TASK051 SHIELD NETWORK SERVER PASS two clients, taunt RPC, authoritative target priority")
	quit(0)
func _fail(reason: String) -> void:
	printerr("TASK051 SHIELD NETWORK SERVER FAIL: "+reason)
	quit(1)
