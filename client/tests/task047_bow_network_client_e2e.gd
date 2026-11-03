extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var attacker := OS.get_cmdline_user_args().has("--attacker")
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	game.selected_avatar = 2 if attacker else 0
	game._join_websocket("ws://127.0.0.1:7788")
	for frame in 450:
		await process_frame
		if game.own_id > 0 and game.players.size() == 2 and game.wolf_alive and (not attacker or (game.live_ui.state.amount("arrow") == 3 and game.live_ui.state.amount("bow") == 1)):
			break
	if game.players.size() != 2 or not game.wolf_alive:
		_fail("world state not replicated")
		return
	if attacker:
		if game.live_ui.hud.hotbar.slot_buttons["bow"].disabled:
			_fail("craftable bow remains disabled in live hotbar")
			return
		game.live_ui.hud.hotbar.slot_buttons["bow"].pressed.emit()
		for frame in 180:
			await process_frame
			if game.live_ui.combat_equipment == "bow":
				break
		if game.live_ui.combat_equipment != "bow" or game.live_ui.state.amount("arrow") != 3 or not game.live_ui.bow_aim_hint.visible:
			_fail("bow equipment, ammo or reticle not replicated")
			return
		game.input_driver.yaw = 0.0
		game.input_driver.pitch = -0.05
		game._try_attack()
		for frame in 200:
			await process_frame
			if game.live_ui.state.amount("arrow") == 2:
				break
		if game.live_ui.state.amount("arrow") != 2 or game.wolf_health != 60:
			_fail("miss ammo or health snapshot incorrect")
			return
		await create_timer(0.72).timeout
		var origin: Vector3 = game.players[game.own_id].position + Vector3.UP*0.8
		var target: Vector3 = game.wolf_position + Vector3.UP*0.65
		var to_target: Vector3 = target-origin
		game.input_driver.yaw = atan2(-to_target.x,-to_target.z)
		game.input_driver.pitch = clampf(atan2(to_target.y,Vector2(to_target.x,to_target.z).length()),-1.25,-0.05)
		game._try_attack()
		for frame in 250:
			await process_frame
			if game.live_ui.state.amount("arrow") == 1 and game.wolf_health == 40:
				break
		if game.live_ui.state.amount("arrow") != 1 or game.wolf_health != 40:
			_fail("aimed shot result not replicated")
			return
	else:
		for frame in 450:
			await process_frame
			if game.wolf_health == 40:
				break
		if game.wolf_health != 40:
			_fail("observer did not see target damage")
			return
		if game.live_ui.state.amount("arrow") != 0:
			_fail("witness has someone else's ammo")
			return
	print("TASK047 BOW NETWORK CLIENT PASS "+("ATTACKER" if attacker else "WITNESS"))
	game._disconnect()
	quit(0)
func _fail(why: String) -> void:
	printerr("TASK047 BOW NETWORK CLIENT FAIL: "+why)
	quit(1)
