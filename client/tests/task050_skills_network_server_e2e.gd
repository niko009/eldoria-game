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
		_fail("two players did not connect")
		return
	var veteran := -1
	var beginner := -1
	for id in game.players:
		if int(game.player_choices[id]) == 2:
			veteran = int(id)
		else:
			beginner = int(id)
	if veteran < 0 or beginner < 0:
		_fail("player roles invalid")
		return
	game.set_physics_process(false)
	# Spawn order changes across runs. Keep the target on a deterministic
	# obstacle-free firing line so this test measures skill damage, not RNG.
	var world: Node3D = game.get_node("Eldoria_Forest")
	var safe_start := Vector3(0,world.height_at(0,0)+1,0)
	for id in [veteran,beginner]:
		game.players[id].position = safe_start
		game.correct_own_position.rpc_id(id,safe_start)
	for id in [veteran,beginner]:
		var inventory: Dictionary = game._empty_inventory()
		inventory["bow"] = 1
		inventory["arrow"] = 1
		game.player_inventories[id] = inventory
		game.player_skills[id] = {"archery": 400 if id == veteran else 0,"spear":0,"defense":0}
		game.inventory_snapshot.rpc_id(id,inventory)
		game.skill_snapshot.rpc_id(id,game.player_skills[id])
		if not game._equip_combat_on_server(id,"bow"):
			_fail("bow not equipped on server")
			return
	var start: Vector3 = game.players[veteran].position
	game.wolf_position = Vector3(start.x+4, world.height_at(start.x+4,start.z)+0.1,start.z)
	var direction: Vector3 = (game.wolf_position+Vector3.UP*0.65-(start+Vector3.UP*0.8)).normalized()
	if world.arrow_block_fraction(start+Vector3.UP*0.8,start+Vector3.UP*0.8+direction*6.0)*6.0 < 3.0:
		_fail("chosen training lane is occluded")
		return
	game.wolf_health = 60
	game.wolf_alive = true
	game.pack_wolves.clear()
	game.wolf_snapshot.rpc(game.wolf_position,game.wolf_health,true,Vector3.ZERO)
	print("TASK050 SERVER READY veteran=",veteran, " at=",game.players[veteran].position," wolf=",game.wolf_position," xp=",game.player_skills[veteran])
	for frame in 600:
		await process_frame
		if int(game.player_inventories[veteran].get("arrow",-1)) == 0:
			break
	if game.wolf_health != 32 or game.player_skills[veteran]["archery"] != 402:
		_fail("high-level player did not deal 28 and receive personal XP: hp="+str(game.wolf_health)+" xp="+str(game.player_skills.get(veteran,{})))
		return
	for frame in 600:
		await process_frame
		if int(game.player_inventories[beginner].get("arrow",-1)) == 0:
			break
	if game.wolf_health != 12 or game.player_skills[beginner]["archery"] != 2:
		_fail("low-level player did not deal 20 and receive personal XP: hp="+str(game.wolf_health))
		return
	if game.player_skills[veteran]["archery"] != 402 or game.player_skills[beginner]["archery"] != 2:
		_fail("skills contaminated across players")
		return
	await create_timer(0.35).timeout
	print("TASK050 SKILL NETWORK SERVER PASS different server-owned damage, personal XP, 2 clients")
	quit(0)
func _fail(why: String) -> void:
	printerr("TASK050 SKILL NETWORK SERVER FAIL: "+why)
	quit(1)
