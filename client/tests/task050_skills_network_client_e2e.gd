extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var veteran := OS.get_cmdline_user_args().has("--veteran")
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	game.selected_avatar = 2 if veteran else 0
	game._join_websocket("ws://127.0.0.1:7788")
	var initial_xp := 400 if veteran else 0
	for frame in 600:
		await process_frame
		if game.own_id > 0 and game.players.size() == 2 and game.wolf_alive and game.live_ui.combat_equipment == "bow" and game.live_ui.state.amount("arrow") == 1 and int(game.live_ui.hud.last_skills.get("archery",-1)) == initial_xp:
			break
	if game.own_id == 0 or game.players.size() != 2 or game.live_ui.state.amount("arrow") != 1 or int(game.live_ui.hud.last_skills.get("archery",-1)) != initial_xp:
		_fail("initial network inventory or skills not replicated")
		return
	if not veteran:
		for frame in 600:
			await process_frame
			if game.wolf_health == 32:
				break
		if game.wolf_health != 32:
			_fail("beginner did not see veteran damage")
			return
	else:
		await create_timer(0.45).timeout
	var origin: Vector3 = game.players[game.own_id].position + Vector3.UP*0.8
	var to_target: Vector3 = game.wolf_position+Vector3.UP*0.65-origin
	print("TASK050 AIM ", "veteran" if veteran else "beginner", " origin=",origin," wolf=",game.wolf_position," before_xp=",game.live_ui.hud.last_skills.get("archery",-1))
	game.input_driver.yaw = atan2(-to_target.x,-to_target.z)
	game.input_driver.pitch = clampf(atan2(to_target.y,Vector2(to_target.x,to_target.z).length()),-1.25,-0.05)
	game._try_attack()
	var target_hp := 32 if veteran else 12
	for frame in 650:
		await process_frame
		if game.live_ui.state.amount("arrow") == 0 and game.wolf_health == target_hp and int(game.live_ui.hud.last_skills.get("archery",-1)) == initial_xp+2:
			break
	if game.live_ui.state.amount("arrow") != 0 or game.wolf_health != target_hp or int(game.live_ui.hud.last_skills.get("archery",-1)) != initial_xp+2:
		_fail("network skill bonus or XP incorrect: hp=%d arrows=%d xp=%d" % [game.wolf_health,game.live_ui.state.amount("arrow"),int(game.live_ui.hud.last_skills.get("archery",-1))])
		return
	print("TASK050 SKILL NETWORK CLIENT PASS "+("VETERAN" if veteran else "BEGINNER"))
	# Keep the connection open while the authoritative test server verifies
	# both players' XP. Disconnection intentionally cleans player_skills.
	await create_timer(1.4).timeout
	game._disconnect()
	quit(0)
func _fail(why: String) -> void:
	printerr("TASK050 SKILL NETWORK CLIENT FAIL: "+why)
	quit(1)
