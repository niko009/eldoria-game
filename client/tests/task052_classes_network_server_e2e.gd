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
		_fail("missing two player connections")
		return
	game.set_physics_process(false)
	var mage := -1
	var rogue := -1
	for id in game.players:
		if int(game.player_choices[id]) == 2:
			mage = int(id)
		elif int(game.player_choices[id]) == 1:
			rogue = int(id)
	if mage < 0 or rogue < 0:
		_fail("class selection not synchronized")
		return
	var world: Node3D = game.get_node("Eldoria_Forest")
	var anchor := Vector3(0,world.height_at(0,0)+1,0)
	game.players[mage].position = anchor
	game.players[rogue].position = anchor+Vector3(0,0,2)
	game.correct_own_position.rpc_id(mage,game.players[mage].position)
	game.correct_own_position.rpc_id(rogue,game.players[rogue].position)
	game.player_health[mage] = 100
	game.player_health[rogue] = 50
	game.health_snapshot.rpc_id(mage,100,100)
	game.health_snapshot.rpc_id(rogue,50,100)
	game.health_snapshot_for.rpc(mage,100)
	game.health_snapshot_for.rpc(rogue,50)
	game.hero_mana[mage] = 100.0
	game.mana_snapshot.rpc_id(mage,100)
	for i in 500:
		await process_frame
		if game.player_health[rogue] == 85:
			break
	if game.player_health[rogue] != 85 or int(game.hero_mana[mage]) != 60:
		_fail("Mage heal RPC failed or mana consumption incorrect")
		return
	var before: Vector3 = game.players[rogue].position
	for i in 440:
		await process_frame
		if game.players[rogue].position.distance_to(before) > 1.0:
			break
	var dash_dist: float = game.players[rogue].position.distance_to(before)
	if dash_dist <= 1.0 or dash_dist > 2.65:
		_fail("Rogue dash RPC failed or distance incorrect: "+str(dash_dist))
		return
	if game.hero_ability_ready_at.get(rogue,0) <= 0:
		_fail("Rogue cooldown not recorded on server")
		return
	await create_timer(0.75).timeout
	print("TASK052 HERO NETWORK SERVER PASS two clients, Mage heals Rogue, Rogue dashes, isolated server state")
	quit(0)
func _fail(message: String) -> void:
	printerr("TASK052 HERO NETWORK SERVER FAIL: "+message)
	quit(1)
