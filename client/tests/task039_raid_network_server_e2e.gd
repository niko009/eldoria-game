extends SceneTree
# Dedicated WebSocket host: verifies raid/health/rewards replicated to two peers.
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	for frame in 600:
		await process_frame
		if game.players.size() == 2:
			break
	if game.players.size() != 2:
		_fail("two clients did not connect")
		return
	var attacker := -1
	var medic := -1
	for id in game.players:
		if int(game.player_choices[id]) == 2:
			attacker = int(id)
		else:
			medic = int(id)
	if attacker < 0 or medic < 0:
		_fail("player roles unavailable")
		return
	game.placed_buildings[901] = {"kind":"campfire","x":0.0,"z":0.0}
	game.building_snapshot.rpc(game.placed_buildings)
	for id in [attacker,medic]:
		game.player_inventories[id] = {"wood":0,"stone":0,"herb":4,"axe":0}
		game.inventory_snapshot.rpc_id(id,game.player_inventories[id])
	game.player_inventories[attacker]["shield"] = 1
	if not game._equip_combat_on_server(attacker,"shield"):
		_fail("attacker could not equip shield")
		return
	game.player_health[medic] = 60
	game.health_snapshot.rpc_id(medic,60,100)
	game.health_snapshot_for.rpc(medic,60)
	game.raid.deadline_ms = Time.get_ticks_msec() - 1
	game._combat_server_tick(0.02)
	if game.raid.phase != "night":
		_fail("authoritative raid not started")
		return
	if game.pack_wolves.size() != 2:
		_fail("two simultaneous independent pack wolves missing")
		return
	for pack_id in [1,2]:
		if not game.pack_wolves[pack_id]["alive"] or int(game.pack_wolves[pack_id]["hp"]) != 60:
			_fail("pack wolf identity or HP missing")
			return
	for frame in 210:
		await process_frame
		if game.player_health[medic] == 95:
			break
	if game.player_health[medic] != 95 or int(game.player_inventories[medic]["herb"]) != 2:
		_fail("remote heal not performed " + str(game.player_health) + " " + str(game.player_inventories))
		return
	# Allow the medic client to receive and assert the heal snapshot before
	# the victory reward sends a newer herb balance.
	await create_timer(1.1).timeout
	# The attacker defeats one independently tracked pack member first.
	var pack_at: Vector3 = game.pack_wolves[1]["position"]
	game.players[attacker].position = Vector3(pack_at.x+0.6,pack_at.y+0.9,pack_at.z)
	for strike in 3:
		game.last_attack_at.erase(attacker)
		if not game._attack_on_server(attacker):
			_fail("pack wolf hit rejected %d" % strike)
			return
	if game.pack_wolves[1]["alive"] or game.raid.kills != 1 or not game.pack_wolves[2]["alive"]:
		_fail("pack wolf damage/independent identity invalid")
		return
	for round_index in 3:
		var pos: Vector3 = game.players[attacker].position
		game.wolf_position = Vector3(pos.x+0.9,pos.y-0.9,pos.z)
		game.wolf_alive = true
		game.wolf_health = 60
		game.wolf_snapshot.rpc(game.wolf_position,60,true,Vector3.ZERO)
		for strike in 3:
			game.last_attack_at.erase(attacker)
			if not game._attack_on_server(attacker):
				_fail("attacker rejected round %d hit %d" % [round_index,strike])
				return
		if round_index < 2:
			game.wolf_respawn_at = Time.get_ticks_msec()-1
			game._combat_server_tick(0.02)
	if game.raid.phase != "intermission" or game.raid.kills != 4:
		_fail("raid victory not registered")
		return
	if int(game.player_inventories[attacker]["herb"]) != 6 or int(game.player_inventories[medic]["herb"]) != 4:
		_fail("different players got incorrect individual raid rewards")
		return
	for frame in 620:
		await process_frame
	print("TASK039 RAID NETWORK SERVER PASS two peers, real heal RPC, four wolf kills, individual persistent rewards")
	quit(0)
func _fail(reason: String) -> void:
	printerr("TASK039 RAID NETWORK SERVER FAIL: "+reason)
	quit(1)
