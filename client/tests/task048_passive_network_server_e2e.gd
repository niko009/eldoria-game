extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	for i in range(520):
		await process_frame
		if game.players.size() == 2:
			break
	if game.players.size() != 2:
		_fail("two players missing")
		return
	game.set_physics_process(false)
	var hunter := -1
	var observer := -1
	for id in game.players:
		if game.player_choices[id] == 2:
			hunter = int(id)
		else:
			observer = int(id)
	if hunter < 0 or observer < 0:
		_fail("network roles missing")
		return
	var animal: Dictionary = game.passive_creatures[1]
	var at: Vector3 = animal["position"]
	var hunter_spot := at + Vector3(0.6,0.9,0)
	game.players[hunter].position = hunter_spot
	game.correct_own_position.rpc_id(hunter,hunter_spot)
	game.passive_snapshot.rpc(1,animal["species"],at,int(animal["hp"]),true,Vector3.ZERO)
	for i in range(350):
		await process_frame
		if int(game.practice_points.get(hunter,0)) == 2:
			break
	if int(animal["hp"]) != 4 or int(game.practice_points.get(hunter,0)) != 2:
		_fail("network hit did not deduct rabbit HP or credit hunter")
		return
	for i in range(350):
		await process_frame
		if not animal["alive"]:
			break
	if animal["alive"] or int(game.practice_points.get(hunter,0)) != 9:
		_fail("network defeat did not credit hunter")
		return
	if int(game.practice_points.get(observer,0)) != 0:
		_fail("observer incorrectly credited training")
		return
	await create_timer(0.5).timeout
	print("TASK048 PASSIVE NETWORK SERVER PASS two clients, isolated practice, disappearance")
	quit(0)
func _fail(message: String) -> void:
	printerr("TASK048 PASSIVE NETWORK SERVER FAIL: "+message)
	quit(1)
