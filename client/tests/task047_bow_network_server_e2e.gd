extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	for frame in 520:
		await process_frame
		if game.players.size() == 2:
			break
	if game.players.size() != 2:
		_fail("two clients did not connect")
		return
	var attacker := -1
	var witness := -1
	for id in game.players:
		if int(game.player_choices[id]) == 2:
			attacker = int(id)
		else:
			witness = int(id)
	if attacker < 0 or witness < 0:
		_fail("missing role")
		return
	# Disable enemy AI for this deterministic networking test only.
	game.set_physics_process(false)
	game.player_inventories[attacker] = {"wood":0,"stone":0,"herb":0,"bow":1,"arrow":5}
	game.inventory_snapshot.rpc_id(attacker,game.player_inventories[attacker])
	# Do not equip the weapon programmatically. Actual client hotbar must
	# send the equipment RPC, and server has to validate ownership.
	var world: Node3D = game.get_node("Eldoria_Forest")
	var shooter: Vector3 = game.players[attacker].position
	game.wolf_position = Vector3(shooter.x+4, world.height_at(shooter.x+4,shooter.z)+0.1,shooter.z)
	game.wolf_health = 60
	game.wolf_alive = true
	game.wolf_snapshot.rpc(game.wolf_position,game.wolf_health,true,Vector3.ZERO)
	for frame in 240:
		await process_frame
		if game.equipped_combat.get(attacker,"") == "bow":
			break
	if game.equipped_combat.get(attacker,"") != "bow":
		_fail("client hotbar failed to equip bow via authoritative RPC")
		return
	for frame in 240:
		await process_frame
		if int(game.player_inventories[attacker].get("arrow",-1)) == 4:
			break
	if game.wolf_health != 60 or int(game.player_inventories[attacker].get("arrow",-1)) != 4:
		_fail("first shot did not preserve 5 -> 4 arrows")
		return
	for frame in 350:
		await process_frame
		if int(game.player_inventories[attacker].get("arrow",-1)) == 3:
			break
	if game.wolf_health != 40 or int(game.player_inventories[attacker].get("arrow",-1)) != 3:
		_fail("network aimed hit did not damage wolf")
		return
	for expected in [2,1,0]:
		for frame in 270:
			await process_frame
			if int(game.player_inventories[attacker].get("arrow",-1)) == expected:
				break
		if int(game.player_inventories[attacker].get("arrow",-1)) != expected:
			_fail("expected arrow count %d after next shot" % expected)
			return
	if int(game.player_inventories[witness].get("arrow",0)) != 0:
		_fail("second player's ammunition was changed")
		return
	await create_timer(0.8).timeout
	print("TASK047 BOW NETWORK SERVER PASS 5 -> 4 -> 3 -> 2 -> 1 -> 0, no other-player spend")
	quit(0)
func _fail(why: String) -> void:
	printerr("TASK047 BOW NETWORK SERVER FAIL: "+why)
	quit(1)
