extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var is_mage := OS.get_cmdline_user_args().has("--mage")
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	game._choose_avatar(2 if is_mage else 1)
	game._join_websocket("ws://127.0.0.1:7788")
	for i in 470:
		await process_frame
		if game.own_id > 0 and game.players.size() == 2 and game.player_choices.get(game.own_id,-1) == (2 if is_mage else 1):
			break
	if game.own_id <= 0 or game.players.size() != 2:
		_fail("class selection or two-player spawn failed")
		return
	var btn: Button = game.live_ui.hud.action_controls["ability"]
	if btn.get_node("Caption").text != ("ЛЕЧИТЬ" if is_mage else "РЫВОК"):
		_fail("class-specific Android ability button wrong")
		return
	if is_mage:
		game._choose_avatar(0) # Remote class switching outside campfire must not succeed.
		for i in 30:
			await process_frame
		if game.player_choices.get(game.own_id,-1) != 2 or game.live_ui.state.selected_avatar != "mage":
			_fail("unauthorized remote class switch succeeded")
			return
		for i in 380:
			await process_frame
			var has_injured := false
			for id in game.players:
				if id != game.own_id and int(game.player_health.get(id,100)) == 50:
					has_injured = true
			if has_injured:
				break
		btn.pressed.emit()
		for i in 450:
			await process_frame
			if game.live_ui.hero_mana == 60:
				break
		if game.live_ui.hero_mana != 60:
			_fail("Mage did not receive mana cost snapshot")
			return
		if not game.live_ui.hud.mana_label.visible or game.live_ui.hud.mana_label.text != "Мана 60/100":
			_fail("Mage mana gauge not visible in HUD")
			return
		btn.pressed.emit()
		for i in 70:
			await process_frame
		if game.live_ui.hero_mana != 60:
			_fail("Mage bypassed healing cooldown")
			return
	else:
		for i in 450:
			await process_frame
			if int(game.player_health.get(game.own_id,100)) == 85:
				break
		if int(game.player_health.get(game.own_id,100)) != 85:
			_fail("Rogue did not receive teammate heal")
			return
		if game.live_ui.hud.mana_label.visible:
			_fail("Rogue incorrectly sees Mage mana")
			return
		var before: Vector3 = game.players[game.own_id].position
		game.input_driver.yaw = -PI/2.0
		btn.pressed.emit()
		for i in 200:
			await process_frame
			if game.players[game.own_id].position.distance_to(before) >= 1.0:
				break
		if game.players[game.own_id].position.distance_to(before) < 1.0:
			_fail("Rogue dash position not replicated")
			return
	print("TASK052 HERO NETWORK CLIENT PASS "+("MAGE" if is_mage else "ROGUE"))
	await create_timer(0.8).timeout
	game._disconnect()
	quit(0)
func _fail(reason: String) -> void:
	printerr("TASK052 HERO NETWORK CLIENT FAIL: "+reason)
	quit(1)
