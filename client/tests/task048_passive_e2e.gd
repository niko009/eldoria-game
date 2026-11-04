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
	var id: int = game.own_id
	if id <= 0 or game.passive_creatures.size() != 15 or game.passive_actors.size() != 15:
		_fail("wildlife and training dummies missing")
		return
	for creature_id in game.passive_creatures:
		var spawn: Vector3 = game.passive_creatures[creature_id]["home"]
		if game.get_node("Eldoria_Forest").collides_at(Vector2(spawn.x,spawn.z),0.32):
			_fail("animal spawn embedded in obstacle: "+str(creature_id))
			return
	var rabbit: Dictionary = game.passive_creatures[1]
	var at: Vector3 = rabbit["position"]
	game.players[id].position = at + Vector3(0.6,1.0,0)
	var old_distance := Vector2(at.x-game.players[id].position.x,at.z-game.players[id].position.z).length()
	game._tick_passive_creatures(0.10,Time.get_ticks_msec())
	var shifted: Vector3 = rabbit["position"]
	if shifted.distance_to(at) < 0.001:
		_fail("rabbit did not flee from player")
		return
	game.players[id].position = shifted+Vector3(0.6,0.9,0)
	var raid_kills: int = game.raid.kills
	if not game._attack_on_server(id) or int(rabbit["hp"]) != 4 or int(game.practice_points[id]) != 2:
		_fail("first training hit or points invalid")
		return
	game.last_attack_at.erase(id)
	if not game._attack_on_server(id) or bool(rabbit["alive"]) or int(game.practice_points[id]) != 9:
		_fail("defeat or training points invalid")
		return
	if game.raid.kills != raid_kills or game.passive_actors[1].visible:
		_fail("passive defeat changed raid progression or visual state")
		return
	if game._damage_passive_on_server(id,1,30,Time.get_ticks_msec()):
		_fail("dead animal took more damage")
		return
	game._tick_passive_creatures(0.05,int(rabbit["respawn_at"])+1)
	if not rabbit["alive"] or int(rabbit["hp"]) != 24 or game.passive_creatures.size() != 15:
		_fail("passive mob did not respawn")
		return
	var world: Node3D = game.get_node("Eldoria_Forest")
	game.players[id].position = Vector3(0, world.height_at(0,0)+1.0,0)
	rabbit["position"] = Vector3(4,world.height_at(4,0)+0.1,0)
	game.player_inventories[id] = {"bow":1,"arrow":2,"wood":0,"stone":0,"herb":0}
	if not game._equip_combat_on_server(id,"bow"):
		_fail("training bow equip failed")
		return
	var origin: Vector3 = game.players[id].position + Vector3.UP*0.8
	var direction: Vector3 = (rabbit["position"] + Vector3.UP*0.35 - origin).normalized()
	var obstacle: int = world._add_obstacle(Vector2(2,0),0.85)
	game.last_attack_at.erase(id)
	if not game._attack_on_server(id,direction) or int(rabbit["hp"]) != 24:
		_fail("blocked arrow damaged training rabbit")
		return
	world.obstacle_active[obstacle] = false
	game.last_attack_at.erase(id)
	if not game._attack_on_server(id,direction) or int(rabbit["hp"]) != 4:
		_fail("clear arrow did not damage training rabbit")
		return
	if int(game.practice_points[id]) != 11 or int(game.player_inventories[id]["arrow"]) != 0:
		_fail("ranged training points or ammo invalid")
		return
	if game.passive_creatures[5]["species"] != "dummy" or game.passive_creatures[6]["species"] != "dummy":
		_fail("training mannequins not spawned")
		return
	var now := Time.get_ticks_msec()
	var dummy_before := int(game.passive_creatures[5]["hp"])
	if not game._damage_passive_on_server(id,5,20,now):
		_fail("training dummy rejected first hit")
		return
	if int(game.passive_creatures[5]["hp"]) != dummy_before:
		_fail("indestructible training dummy lost HP")
		return
	if game._damage_passive_on_server(id,5,20,now+200) or int(game.player_skills[id]["archery"]) != 5:
		_fail("mannequin cooldown bypassed or skill reward wrong")
		return
	if not game._damage_passive_on_server(id,5,20,now+2001) or int(game.player_skills[id]["archery"]) != 8:
		_fail("mannequin repeat hit did not award capped skill XP")
		return
	print("TASK048 PASSIVE PASS flee, melee/bow practice, obstacle blocking, raid separation, respawn")
	quit(0)
func _fail(message: String) -> void:
	printerr("TASK048 PASSIVE FAIL: "+message)
	quit(1)
