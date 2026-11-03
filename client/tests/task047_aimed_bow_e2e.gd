extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	game._host()
	var id: int = game.own_id
	var world: Node3D = game.get_node("Eldoria_Forest")
	game.players[id].position = Vector3(0, world.height_at(0,0)+1, 0)
	game.player_inventories[id] = {"wood":0,"stone":0,"herb":0,"bow":1,"arrow":4}
	if not game._equip_combat_on_server(id,"bow"):
		_fail("bow equip rejected")
		return
	game.wolf_alive = true
	game.wolf_health = 60
	game.wolf_position = Vector3(4,world.height_at(4,0)+0.1,0)
	game.pack_wolves.clear()
	var origin: Vector3 = game.players[id].position+Vector3.UP*0.8
	var aim: Vector3 = (game.wolf_position+Vector3.UP*0.65-origin).normalized()
	if game._attack_on_server(id, Vector3.ZERO):
		_fail("zero aim was accepted")
		return
	if game._attack_on_server(id, Vector3(99, 0, 0)):
		_fail("non-normalized aim accepted")
		return
	if game.player_inventories[id]["arrow"] != 4:
		_fail("invalid aim consumed ammo")
		return
	if not game._attack_on_server(id, Vector3(0,0,-1)):
		_fail("valid miss should fire")
		return
	if game.wolf_health != 60 or game.player_inventories[id]["arrow"] != 3:
		_fail("miss damaged wolf or did not consume arrow")
		return
	game.last_attack_at.erase(id)
	if not game._attack_on_server(id,aim):
		_fail("aimed shot rejected")
		return
	if game.wolf_health != 40 or game.player_inventories[id]["arrow"] != 2:
		_fail("aimed shot failed to damage")
		return
	var blocker: int = world._add_obstacle(Vector2(2,0),0.9)
	game.last_attack_at.erase(id)
	if not game._attack_on_server(id,aim):
		_fail("blocked shot refused instead of firing")
		return
	if game.wolf_health != 40 or game.player_inventories[id]["arrow"] != 1:
		_fail("tree obstacle failed to prevent damage")
		return
	world.obstacle_active[blocker] = false
	game.last_attack_at.erase(id)
	if not game._attack_on_server(id,aim) or game.wolf_health != 20:
		_fail("cleared obstacle did not restore line of sight")
		return
	if game.player_inventories[id]["arrow"] != 0:
		_fail("ammo inventory incorrect")
		return
	game.last_attack_at.erase(id)
	if game._attack_on_server(id,aim):
		_fail("shot without arrow accepted")
		return
	print("TASK047 AIMED BOW PASS invalid aim, miss, hit, active blocker, removed blocker, ammo")
	quit(0)
func _fail(message: String) -> void:
	printerr("TASK047 AIMED BOW FAIL: "+message)
	quit(1)
