extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var hunter := OS.get_cmdline_user_args().has("--hunter")
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	game.selected_avatar = 2 if hunter else 0
	game._join_websocket("ws://127.0.0.1:7788")
	for frame in 500:
		await process_frame
		if game.own_id > 0 and game.players.size() == 2 and game.passive_actors.size() == 6:
			break
	if game.passive_actors.size() != 6:
		_fail("passive wildlife not replicated")
		return
	if not game.passive_actors[1].visible or game.passive_actors[1].species != "rabbit":
		_fail("initial rabbit state wrong")
		return
	if hunter:
		for frame in 100:
			await process_frame
			if game.players[game.own_id].position.x < -5.0:
				break
		game._try_attack()
		for frame in 240:
			await process_frame
			if game.live_ui.hud.last_practice_points == 2:
				break
		if game.live_ui.hud.last_practice_points != 2:
			_fail("training points did not reach hunter")
			return
		await create_timer(0.75).timeout
		game._try_attack()
	for frame in 600:
		await process_frame
		if not game.passive_actors[1].visible:
			break
	if game.passive_actors[1].visible:
		_fail("animal defeat not synchronized")
		return
	if hunter:
		if game.live_ui.hud.last_practice_points != 9:
			_fail("hunter final training points mismatch")
			return
	elif game.live_ui.hud.last_practice_points != 0:
		_fail("observer received hunter points")
		return
	print("TASK048 PASSIVE NETWORK CLIENT PASS "+("HUNTER" if hunter else "OBSERVER"))
	game._disconnect()
	quit(0)
func _fail(message: String) -> void:
	printerr("TASK048 PASSIVE NETWORK CLIENT FAIL: "+message)
	quit(1)
