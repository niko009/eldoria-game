extends SceneTree

# Run as independent Godot processes (host and client). The client rejoins
# using the same running process, not a fresh instance.
# The harness exercises actual ENet packets over 127.0.0.1:7777.
const SCENE := preload("res://Main.tscn")
var game: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	var role := "host" if arguments.has("--host") else "client"
	game = SCENE.instantiate()
	root.add_child(game)
	await process_frame
	if role == "host":
		game._host()
	else:
		game._join()
	if not await _await_players(2, 300):
		_fail("initial connection did not yield two actors (%s)" % game.players.size())
		return
	var my_id: int = game.own_id
	var remote_id: int = _other_id(my_id)
	var my_start: Vector3 = game.players[my_id].position
	var remote_start: Vector3 = game.players[remote_id].position
	print("E2E CONNECT role=%s id=%s players=%s own=%s remote=%s" % [role,my_id,game.players.size(),my_start,remote_start])
	if absf(remote_start.y - 1.0) > 0.01:
		_fail("remote capsule spawn y must equal 1.0, got %.2f" % remote_start.y)
		return
	Input.action_press("move_right" if role == "host" else "move_left")
	for i in range(100):
		await process_frame
	Input.action_release("move_right" if role == "host" else "move_left")
	for i in range(60):
		await process_frame
	if game.players[my_id].position.distance_to(my_start) < 1.0:
		_fail("local movement missing")
		return
	if game.players[remote_id].position.distance_to(remote_start) < 1.0:
		_fail("remote movement not replicated")
		return
	print("E2E MOVEMENT PASS role=%s local=%.2f remote=%.2f" % [role,game.players[my_id].position.distance_to(my_start),game.players[remote_id].position.distance_to(remote_start)])
	if role == "client":
		game._disconnect()
		if game.own_id != 0 or not game.players.is_empty():
			_fail("disconnect did not reset client state")
			return
		for i in range(20):
			await process_frame
		game._join()
		if not await _await_players(2, 300):
			_fail("same client process failed to reconnect")
			return
		my_id = game.own_id
		remote_id = _other_id(my_id)
		my_start = game.players[my_id].position
		remote_start = game.players[remote_id].position
		if absf(remote_start.y - 1.0) > 0.01:
			_fail("reconnect changed remote capsule elevation")
			return
		Input.action_press("move_left")
		for i in range(100):
			await process_frame
		Input.action_release("move_left")
		for i in range(60):
			await process_frame
		if game.players[my_id].position.distance_to(my_start) < 1.0:
			_fail("client failed to move after reconnect")
			return
		if game.players[remote_id].position.distance_to(remote_start) < 1.0:
			_fail("host movement absent after reconnect")
			return
		print("E2E CLIENT REJOIN PASS, movement on both peers")
		game._disconnect()
		quit(0)
		return
	if not await _await_players(1, 200):
		_fail("client disconnect was not observed")
		return
	print("E2E DISCONNECT PASS")
	if not await _await_players(2, 360):
		_fail("second client did not reconnect")
		return
	remote_id = _other_id(my_id)
	remote_start = game.players[remote_id].position
	# Move toward the clear spawn, rather than into the blocking rock at x~5.
	Input.action_press("move_left")
	for i in range(100):
		await process_frame
	Input.action_release("move_left")
	for i in range(60):
		await process_frame
	if game.players[remote_id].position.distance_to(remote_start) < 1.0:
		_fail("reconnected client's movement did not replicate")
		return
	if not await _await_players(1, 200):
		_fail("reconnected client did not finish and disconnect")
		return
	print("E2E RECONNECT PASS, second player movement replicated")
	quit(0)

func _other_id(own: int) -> int:
	for id in game.players.keys():
		if id != own:
			return id
	return -1

func _await_players(count: int, frames: int) -> bool:
	for i in range(frames):
		if game.players.size() == count:
			return true
		await process_frame
	return false

func _fail(message: String) -> void:
	printerr("E2E FAIL: " + message)
	quit(1)