extends SceneTree
const GAME := preload("res://Main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	game._host()
	game.set_physics_process(false)
	var defender: int = game.own_id
	var archer := 5051
	var world: Node3D = game.get_node("Eldoria_Forest")
	var start: Vector3 = Vector3(0,world.height_at(0,0)+1,0)
	game.players[defender].position = start + Vector3(0,0,7)
	game._spawn(archer,start+Vector3(0,0,2),1)
	game.player_health[archer] = 100
	game.player_inventories[defender] = game._empty_inventory()
	game.player_inventories[archer] = game._empty_inventory()
	game.player_inventories[defender]["shield"] = 1
	game.wolf_alive = true
	game.wolf_position = start
	game.pack_wolves = {51: {"alive":true,"position":start+Vector3(2,0,0),"hp":60,"direction":Vector3.ZERO,"last_hit":0},
		52: {"alive":true,"position":start+Vector3(-2,0,0),"hp":60,"direction":Vector3.ZERO,"last_hit":0}}
	var now := Time.get_ticks_msec()
	if game._choose_wolf_target(start,now) != archer:
		_fail("wolf should prefer nearby archer before taunt")
		return
	if game._shield_taunt_on_server(defender,now):
		_fail("taunt without equipped shield accepted")
		return
	if not game._equip_combat_on_server(defender,"shield"):
		_fail("server refused shield equip")
		return
	if game.live_ui.hud.action_controls["attack"].get_node("Caption").text != "ЗОВ":
		_fail("shield button caption not updated")
		return
	game._try_attack() # reuse keyboard/touch attack action on the host
	var cast_at: int = int(game.shield_taunt_until.get(defender,0))
	if cast_at <= now or game._choose_wolf_target(start,now) != defender:
		_fail("shield attack input did not taunt primary wolf")
		return
	if game.players[defender].get_node_or_null("TauntIndicator") == null:
		_fail("defender marker missing for teammates")
		return
	for enemy in game.pack_wolves.values():
		if game._choose_wolf_target(enemy["position"],now) != defender:
			_fail("shield taunt did not influence pack wolves")
			return
	var expires_at: int = cast_at
	if game._shield_taunt_on_server(defender,now+10):
		_fail("shield cooldown bypassed")
		return
	if game._choose_wolf_target(start,expires_at+1) != archer:
		_fail("taunt did not expire")
		return
	if game._shield_taunt_on_server(defender,now+10000):
		_fail("shield cooldown reset too early")
		return
	if not game._shield_taunt_on_server(defender,now+16000):
		_fail("shield taunt did not recover after cooldown")
		return
	game.player_health[defender] = 0
	if game._shield_taunt_on_server(defender,now+32000) or game._choose_wolf_target(start,now+16001) != archer:
		_fail("dead defender still attracts wolves")
		return
	game.player_health[defender] = 100
	if not game._equip_combat_on_server(defender,"unarmed"):
		_fail("unequip shield failed")
		return
	if game._choose_wolf_target(start,now+16001) != archer or game.live_ui.hud.action_controls["attack"].get_node("Caption").text != "УДАР":
		_fail("unequipped defender retains taunt")
		return
	await process_frame
	if game.players[defender].get_node_or_null("TauntIndicator") != null:
		_fail("taunt visual marker survives unequipping the shield")
		return
	game.wolf_alive = false
	game.pack_wolves.clear()
	game.shield_taunt_ready_at.erase(defender)
	game._equip_combat_on_server(defender,"shield")
	if game._shield_taunt_on_server(defender,now+40000):
		_fail("taunt consumed with no wolves around")
		return
	print("TASK051 SHIELD TAUNT PASS server-only input, pack priority, timed expiry, cooldown, death, equipment, empty range")
	quit(0)

func _fail(reason: String) -> void:
	printerr("TASK051 SHIELD TAUNT FAIL: "+reason)
	quit(1)
