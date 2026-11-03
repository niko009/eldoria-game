extends SceneTree
const GAME := preload("res://Main.tscn")
const RAID := preload("res://camp_raid.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var logic: RefCounted = RAID.new()
	logic.begin(1000)
	if logic.advance(90000) != "" or logic.advance(91000) != "night_started":
		_fail("preparation timing/transition invalid")
		return
	if logic.wolf_defeated(91001) != "wolf_defeated" or logic.kills != 1:
		_fail("score failed")
		return
	if logic.wolf_defeated(91001) != "wolf_defeated" or logic.wolf_defeated(91001) != "wolf_defeated":
		_fail("cooperative progress lost")
		return
	if logic.wolf_defeated(91001) != "night_won" or logic.wolf_defeated(91001) != "":
		_fail("raid can be rewarded twice")
		return
	if logic.phase != "intermission" or logic.advance(99001) != "prepare_started" or logic.round != 2:
		_fail("new preparation cycle not started")
		return
	logic.deadline_ms = 1
	if logic.advance(100000) != "night_started" or logic.advance(240001) != "night_failed":
		_fail("night failure/timeout invalid")
		return
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	game._host()
	var id: int = game.own_id
	if id == 0:
		_fail("host unavailable")
		return
	# No campfire, no free healing. No client can declare their own HP.
	game.player_health[id] = 50
	game.player_inventories[id] = {"wood":2,"stone":2,"herb":7,"axe":0}
	if game._heal_on_server(id):
		_fail("healed without a campfire")
		return
	# Local test places a real campfire record, not a fake client-range flag.
	game.placed_buildings[80] = {"kind":"campfire","x":0.0,"z":0.0}
	if not game._heal_on_server(id):
		_fail("server rejected an authorized camp heal")
		return
	if game.player_health[id] != 85 or int(game.player_inventories[id]["herb"]) != 5:
		_fail("healing didn't spend two herbs and restore 35 HP")
		return
	if game._heal_on_server(id) or game.player_health[id] != 85:
		_fail("healing cooldown bypass")
		return
	game.healing_cooldowns.erase(id)
	game.player_inventories[id]["herb"] = 1
	if game._heal_on_server(id):
		_fail("healed without two herbs")
		return
	game.player_inventories[id]["herb"] = 3
	game.players[id].position = Vector3(35,1,35)
	if game._heal_on_server(id):
		_fail("healed outside camp")
		return
	# Advance server clock instantly for deterministic tests.
	game.players[id].position = Vector3(0,1,0)
	game.raid.deadline_ms = Time.get_ticks_msec() - 1
	game._combat_server_tick(0.02)
	if game.raid.phase != "night" or game.raid.kills != 0 or not game.wolf_alive:
		_fail("night didn't spawn a server-controlled raider")
		return
	for round_number in range(game.raid.WOLVES_PER_NIGHT):
		var at: Vector3 = game.wolf_position
		var world: Node3D = game.get_node("Eldoria_Forest")
		game.players[id].position = Vector3(at.x+0.7,world.height_at(at.x+0.7,at.z)+1.0,at.z)
		for strike in 3:
			game.last_attack_at.erase(id)
			if not game._attack_on_server(id):
				_fail("hit was refused for raid wolf %d strike %d" % [round_number,strike])
				return
		if round_number != game.raid.WOLVES_PER_NIGHT-1:
			if game.raid.kills != round_number+1:
				_fail("wave score didn't increase")
				return
			game.wolf_respawn_at = Time.get_ticks_msec() - 1
			game._combat_server_tick(0.02)
			if not game.wolf_alive:
				_fail("next wolf not spawned")
				return
	if game.raid.phase != "intermission" or game.raid.kills != 4:
		_fail("co-op defense not completed")
		return
	if int(game.player_inventories[id]["herb"]) != 5 or int(game.player_inventories[id]["stone"]) != 4:
		_fail("survivor did not get exactly one +2 herb/+2 stone reward")
		return
	if game.raid.wolf_defeated(Time.get_ticks_msec()) != "":
		_fail("duplicate reward possible")
		return
	if game.live_ui == null or not game.live_ui.hud.raid_banner.visible:
		_fail("raid HUD absent")
		return
	game._disconnect()
	print("TASK039 CAMP RAID PASS day/night, sequential wolves, one-time reward, healing cost/range/cooldown, client HUD")
	quit(0)

func _fail(reason: String) -> void:
	printerr("TASK039 CAMP RAID FAIL: " + reason)
	quit(1)
