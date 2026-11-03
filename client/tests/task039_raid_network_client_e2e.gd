extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var medic := OS.get_cmdline_user_args().has("--medic")
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	game.selected_avatar = 0 if medic else 2
	game._join_websocket("ws://127.0.0.1:7788")
	var connected := false
	for frame in 520:
		await process_frame
		if game.own_id > 0 and game.players.size() == 2 and game.live_ui != null and game.live_ui.hud.raid_banner.visible and game.live_ui.hud.raid_banner.text.contains("НОЧНАЯ"):
			connected = true
			break
	if not connected:
		_fail("raid snapshot not replicated to " + ("medic" if medic else "attacker"))
		return
	if medic:
		for frame in 120:
			await process_frame
			for player_id in game.players:
				if int(player_id) != game.own_id and game.players[player_id].combat_item == "shield":
					break
			var found := false
			for player_id in game.players:
				if int(player_id) != game.own_id and game.players[player_id].combat_item == "shield":
					found = true
			if found:
				break
		var visual_ok := false
		for player_id in game.players:
			if int(player_id) != game.own_id and game.players[player_id].combat_item == "shield" and game.players[player_id].combat_visual != null:
				visual_ok = true
		if not visual_ok:
			_fail("remote shield equipment visual was not replicated")
			return
	for frame in 120:
		await process_frame
		if game.pack_actors.size() == 2:
			break
	if game.pack_actors.size() != 2:
		_fail("two simultaneous wolf actors not replicated")
		return
	if medic:
		for frame in 300:
			await process_frame
			if game.live_ui.state.health == 60 and game.live_ui.state.amount("herb") == 4 and game.placed_buildings.has(901):
				break
		if game.live_ui.state.health != 60 or not game.placed_buildings.has(901):
			_fail("medic did not receive health/camp snapshot")
			return
		game._try_heal_at_camp()
		for frame in 350:
			await process_frame
			if game.live_ui.state.health == 95 and game.live_ui.state.amount("herb") == 2:
				break
		if game.live_ui.state.health != 95 or game.live_ui.state.amount("herb") != 2:
			_fail("authoritative healing response missing: hp=%d herbs=%d world=%s" % [game.live_ui.state.health, game.live_ui.state.amount("herb"), str(game.placed_buildings)])
			return
	var won := false
	for frame in 1100:
		await process_frame
		if game.live_ui.hud.raid_banner.text.contains("ПЕРЕДЫШКА") and game.live_ui.state.amount("stone") == 2:
			won = true
			break
	if not won:
		_fail("shared night victory or individual reward not delivered")
		return
	var expected_herb := 4 if medic else 6
	if game.live_ui.state.amount("herb") != expected_herb:
		_fail("individual inventory not synchronized, herbs=" + str(game.live_ui.state.amount("herb")))
		return
	print("TASK039 RAID NETWORK CLIENT PASS "+("MEDIC" if medic else "ATTACKER"))
	for frame in 40:
		await process_frame
	game._disconnect()
	quit(0)

func _fail(message: String) -> void:
	printerr("TASK039 RAID NETWORK CLIENT FAIL: "+message)
	quit(1)
