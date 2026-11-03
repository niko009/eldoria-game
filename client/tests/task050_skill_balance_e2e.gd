extends SceneTree
const GAME := preload("res://Main.tscn")
const PROGRESSION := preload("res://combat_progression.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for test_case in [
		[0,1,0], [24,1,0], [25,2,1], [99,2,1], [100,3,2],
		[225,4,3], [400,5,4], [1000000,201,4]]:
		if PROGRESSION.level_for_xp(test_case[0]) != test_case[1] or PROGRESSION.bonus_tiers(test_case[0]) != test_case[2]:
			_fail("XP tier boundary incorrect: "+str(test_case))
			return
	if PROGRESSION.xp_required_for_level(2) != 25 or PROGRESSION.xp_required_for_level(5) != 400:
		_fail("level threshold not stable")
		return
	if PROGRESSION.weapon_damage("bow",0) != 20 or PROGRESSION.weapon_damage("bow",400) != 28:
		_fail("bow damage formula changed")
		return
	if PROGRESSION.weapon_damage("spear",0) != 30 or PROGRESSION.weapon_damage("spear",400) != 38:
		_fail("spear damage formula changed")
		return
	if PROGRESSION.weapon_damage("unknown",1000000) != 0 or PROGRESSION.level_for_xp(-100) != 1:
		_fail("unsupported weapon or invalid XP changed combat bonus")
		return
	if PROGRESSION.shield_damage_taken(20,0) != 12 or PROGRESSION.shield_damage_taken(20,400) != 8 or PROGRESSION.shield_damage_taken(20,1000000) != 8:
		_fail("shield damage formula or cap changed")
		return
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	game.selected_avatar = 1 # Rogue: preserve the class-independent base shield balance assertions
	game._host()
	game.set_physics_process(false)
	var id: int = game.own_id
	if id < 1:
		_fail("host has no player")
		return
	var world: Node3D = game.get_node("Eldoria_Forest")
	game.players[id].position = Vector3(0,world.height_at(0,0)+1,0)
	game.wolf_position = Vector3(4,world.height_at(4,0)+0.1,0)
	game.wolf_alive = true
	game.wolf_health = 60
	game.pack_wolves.clear()
	game.player_inventories[id] = {"wood":0,"stone":0,"herb":0,"axe":0,"bow":1,"arrow":3,"spear":1,"shield":1}
	var aim: Vector3 = (game.wolf_position+Vector3.UP*0.65 - (game.players[id].position+Vector3.UP*0.8)).normalized()
	game.player_skills[id] = {"archery":0,"spear":0,"defense":0}
	if not game._equip_combat_on_server(id,"bow") or not game._attack_on_server(id,aim) or game.wolf_health != 40:
		_fail("level-one bow did not cause 20 damage")
		return
	game.wolf_health = 60
	game.last_attack_at.erase(id)
	game.player_skills[id]["archery"] = 400
	if not game._attack_on_server(id,aim) or game.wolf_health != 32:
		_fail("level-five bow did not cause 28 damage")
		return
	game.wolf_health = 60
	game.last_attack_at.erase(id)
	game.player_skills[id]["archery"] = 1000000
	if not game._attack_on_server(id,aim) or game.wolf_health != 32 or game.player_inventories[id]["arrow"] != 0:
		_fail("max-XP bow damage cap or ammunition changed")
		return
	game.wolf_health = 60
	game.player_skills[id] = {"archery":0,"spear":0,"defense":0}
	game.players[id].position = game.wolf_position+Vector3(0,1.0,1)
	if not game._equip_combat_on_server(id,"spear"):
		_fail("spear equip rejected")
		return
	game.last_attack_at.erase(id)
	if not game._attack_on_server(id) or game.wolf_health != 30:
		_fail("level-one spear did not cause 30 damage")
		return
	game.wolf_health = 60
	game.player_skills[id]["spear"] = 400
	game.last_attack_at.erase(id)
	if not game._attack_on_server(id) or game.wolf_health != 22:
		_fail("level-five spear did not cause 38 damage")
		return
	game.player_health[id] = 100
	game.player_skills[id]["defense"] = 0
	if not game._equip_combat_on_server(id,"shield"):
		_fail("shield equip rejected")
		return
	if not game._damage_player_on_server(id,20) or game.player_health[id] != 88:
		_fail("level-one shield should absorb 40%")
		return
	game.player_health[id] = 100
	game.player_skills[id]["defense"] = 400
	if not game._damage_player_on_server(id,20) or game.player_health[id] != 92:
		_fail("level-five shield should absorb 60%")
		return
	game.player_health[id] = 100
	game.player_inventories[id]["shield"] = 0
	if not game._damage_player_on_server(id,20) or game.player_health[id] != 80:
		_fail("unowned shield still reduced damage")
		return
	print("TASK050 SKILL BALANCE PASS exact XP levels, capped bow/spear damage, shield reduction, server equipment validation")
	quit(0)

func _fail(message: String) -> void:
	printerr("TASK050 SKILL BALANCE FAIL: "+message)
	quit(1)
