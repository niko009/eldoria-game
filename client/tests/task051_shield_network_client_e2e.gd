extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var defender := OS.get_cmdline_user_args().has("--defender")
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	game.selected_avatar = 0 if defender else 2
	game._join_websocket("ws://127.0.0.1:7788")
	for i in 450:
		await process_frame
		if game.players.size() == 2 and game.wolf_alive and (not defender or game.live_ui.combat_equipment == "shield"):
			break
	if game.players.size() != 2 or not game.wolf_alive:
		_fail("two players and wolf not synchronized")
		return
	if defender:
		if game.live_ui.hud.action_controls["attack"].get_node("Caption").text != "ЗОВ" or game.live_ui.state.amount("shield") != 1:
			_fail("shield action label or owned item missing")
			return
		game._try_attack()
		for i in 240:
			await process_frame
			if game.live_ui.notice.text.contains("Волки отвлечены"):
				break
		if not game.live_ui.notice.text.contains("Волки отвлечены"):
			_fail("remote defender did not get server ability confirmation")
			return
		if game.players[game.own_id].get_node_or_null("TauntIndicator") == null:
			_fail("shield visual marker was not broadcast")
			return
		game._try_attack()
		for i in 240:
			await process_frame
			if game.live_ui.notice.text.contains("перезарядка"):
				break
		if not game.live_ui.notice.text.contains("перезарядка"):
			_fail("server cooldown feedback not delivered")
			return
	else:
		var defender_id := 0
		for id in game.player_choices:
			if game.player_choices[id] == 0:
				defender_id = int(id)
				break
		for i in 320:
			await process_frame
			if defender_id > 0 and game.players.has(defender_id) and game.players[defender_id].get_node_or_null("TauntIndicator") != null:
				break
		if defender_id == 0 or not game.players.has(defender_id) or game.players[defender_id].get_node_or_null("TauntIndicator") == null:
			_fail("teammate cannot see the defender's taunt marker")
			return
		if game.live_ui.hud.action_controls["attack"].get_node("Caption").text != "УДАР" or game.live_ui.state.amount("shield") != 0:
			_fail("nondefender incorrectly owns shield ability")
			return
	print("TASK051 SHIELD NETWORK CLIENT PASS "+("DEFENDER" if defender else "ARCHER"))
	await create_timer(1.0).timeout
	game._disconnect()
	quit(0)
func _fail(reason: String) -> void:
	printerr("TASK051 SHIELD NETWORK CLIENT FAIL: "+reason)
	quit(1)
