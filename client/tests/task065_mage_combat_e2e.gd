extends SceneTree
const GAME := preload("res://Main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	game.selected_avatar = 2
	game._host()
	game.set_physics_process(false)
	var id: int = game.own_id
	var world: Node3D = game.get_node("Eldoria_Forest")
	game.players[id].position = Vector3(0,world.height_at(0,0)+1,0)
	game.wolf_alive = true
	game.wolf_health = 60
	game.wolf_position = Vector3(4,world.height_at(4,0)+0.1,0)
	game.pack_wolves.clear()
	game.hero_mana[id] = 100.0
	var origin: Vector3 = game.players[id].position+Vector3.UP*0.8
	var aim: Vector3 = (game.wolf_position+Vector3.UP*0.65-origin).normalized()
	if game._mage_attack_on_server(id,Vector3.ZERO,0):
		_fail("zero-length aim accepted")
		return
	if game._mage_attack_on_server(id,aim,-1) or game._mage_attack_on_server(id,aim,3):
		_fail("invalid spell accepted")
		return
	if not game._mage_attack_on_server(id,aim,0):
		_fail("fire spell refused")
		return
	if game.wolf_health != 42 or int(game.hero_mana[id]) != 86:
		_fail("fire damage or mana incorrect")
		return
	if game._mage_attack_on_server(id,aim,2):
		_fail("attack bypassed cooldown")
		return
	game.last_attack_at.erase(id)
	if not game._mage_attack_on_server(id,aim,1):
		_fail("frost spell refused")
		return
	if game.wolf_health != 18 or int(game.hero_mana[id]) != 64:
		_fail("frost damage or mana incorrect")
		return
	game.hero_mana[id] = 33.0
	game.last_attack_at.erase(id)
	if game._mage_attack_on_server(id,aim,2):
		_fail("storm allowed without mana")
		return
	game.hero_mana[id] = 100.0
	game.last_attack_at.erase(id)
	if not game._mage_attack_on_server(id,aim,2):
		_fail("storm spell refused")
		return
	if game.wolf_alive or game.wolf_health != 0 or int(game.hero_mana[id]) != 66:
		_fail("storm did not finish target")
		return
	game.player_choices[id] = 0
	game.last_attack_at.erase(id)
	if game._mage_attack_on_server(id,aim,0):
		_fail("knight cast magic")
		return
	game.player_choices[id] = 2
	game.hero_mana[id] = 60.0
	game.player_health[id] = 55
	game._combat_server_tick(1.05)
	if int(game.hero_mana[id]) != 68 or game.player_health[id] != 57:
		_fail("mage did not regenerate mana and health")
		return
	game.player_health[id] = 0
	game._combat_server_tick(1.05)
	if game.player_health[id] != 0 or int(game.hero_mana[id]) != 68:
		_fail("dead mage regenerated")
		return
	print("TASK065 MAGE COMBAT PASS 3 spells, server damage, mana, cooldown, class isolation")
	quit(0)

func _fail(message: String) -> void:
	printerr("TASK065 MAGE COMBAT FAIL: "+message)
	quit(1)