extends SceneTree
const GAME := preload("res://Main.tscn")
const HERO := preload("res://hero_classes.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	game.selected_avatar = HERO.KNIGHT
	game._host()
	game.set_physics_process(false)
	var knight: int = game.own_id
	var rogue := 5201
	var mage := 5202
	var world: Node3D = game.get_node("Eldoria_Forest")
	var start := Vector3(0,world.height_at(0,0)+1,0)
	game.players[knight].position = start
	game._spawn(rogue,start+Vector3(0,0,1),HERO.ROGUE)
	game._spawn(mage,start+Vector3(0,0,2),HERO.MAGE)
	for id in [rogue,mage]:
		game.player_health[id] = 100
		game.player_inventories[id] = game._empty_inventory()
	game.hero_mana[mage] = 100.0
	game.wolf_alive = true
	game.wolf_position = start+Vector3(2,0,0)
	game.pack_wolves.clear()
	# Knight's resistance is independent from shield gear.
	game.player_health[knight] = 100
	if not game._damage_player_on_server(knight,20) or game.player_health[knight] != 82:
		_fail("Knight passive resistance not applied")
		return
	game.player_health[rogue] = 100
	if not game._damage_player_on_server(rogue,20) or game.player_health[rogue] != 80:
		_fail("Rogue received Knight resistance")
		return
	game.player_health[mage] = 100
	if not game._damage_player_on_server(mage,20) or game.player_health[mage] != 80:
		_fail("Mage received Knight resistance")
		return
	# A Rogue with a shield cannot steal Knight's ability.
	game.player_inventories[rogue]["shield"] = 1
	game.equipped_combat[rogue] = "shield"
	if game._shield_taunt_on_server(rogue):
		_fail("Rogue used Knight ability")
		return
	game._equip_combat_on_server(rogue,"unarmed")
	# Dash: valid horizontal direction, collision and cooldown checks.
	var before: Vector3 = game.players[rogue].position
	var now := Time.get_ticks_msec()
	if game._hero_ability_on_server(rogue,Vector3.ZERO,now):
		_fail("Rogue dash accepted invalid direction")
		return
	if not game._hero_ability_on_server(rogue,Vector3(1,0,0),now):
		_fail("Rogue dash refused")
		return
	if game.players[rogue].position.distance_to(before) < 1.5 or game.players[rogue].position.distance_to(before) > HERO.ROGUE_DASH_DISTANCE+0.1:
		_fail("Rogue dash travelled wrong distance")
		return
	if game._hero_ability_on_server(rogue,Vector3.RIGHT,now+1000):
		_fail("Rogue bypassed dash cooldown")
		return
	# Obstacle must stop the dash rather than let it cross trees.
	game.players[rogue].position = before
	var obstacle: int = world._add_obstacle(Vector2(before.x+1.5,before.z),0.6)
	game.hero_ability_ready_at.erase(rogue)
	game._hero_ability_on_server(rogue,Vector3.RIGHT,now+12000)
	if game.players[rogue].position.x > before.x+1.5:
		_fail("Rogue dashed through obstacle")
		return
	world.obstacle_active[obstacle] = false
	# Mage heals the most injured nearby ally; mana is session-only.
	game.player_health[knight] = 50
	game.player_health[rogue] = 70
	game.player_health[mage] = 100
	if not game._hero_ability_on_server(mage,Vector3.ZERO,now+13000):
		_fail("Mage did not heal ally")
		return
	if game.player_health[knight] != 85 or game.player_health[rogue] != 70 or int(game.hero_mana[mage]) != 60:
		_fail("Mage heal target, amount or mana incorrect")
		return
	if int(game.player_skills[mage].get("magic",0)) != 2:
		_fail("Healing an ally should grant mage practice XP")
		return
	if game._hero_ability_on_server(mage,Vector3.ZERO,now+14000):
		_fail("Mage bypassed cooldown")
		return
	game.hero_ability_ready_at.erase(mage)
	game.hero_mana[mage] = 35.0
	if game._hero_ability_on_server(mage,Vector3.ZERO,now+26000):
		_fail("Mage healed without enough mana")
		return
	game.hero_mana[mage] = 100.0
	game.players[knight].position = start+Vector3(30,0,0)
	game.players[rogue].position = start+Vector3(30,0,1)
	game.player_health[mage] = 100
	if game._hero_ability_on_server(mage,Vector3.ZERO,now+30000):
		_fail("Mage healed distant teammates")
		return
	# Server authorizes class changes only while alive and next to campfire.
	game.players[knight].position = start
	if game._change_hero_on_server(knight,HERO.MAGE):
		_fail("class change accepted without campfire")
		return
	game.placed_buildings[970] = {"kind":"campfire","x":start.x,"z":start.z}
	if not game._change_hero_on_server(knight,HERO.MAGE):
		_fail("class change refused at campfire")
		return
	if game.player_choices[knight] != HERO.MAGE or game.hero_mana[knight] != 100:
		_fail("changed class or mana was not reset")
		return
	game.player_health[knight] = 0
	if game._change_hero_on_server(knight,HERO.ROGUE):
		_fail("dead player changed class")
		return
	print("TASK052 HERO CLASSES PASS passives, Knight-only taunt, Rogue dash/obstacles, Mage ally heal/mana, campfire class switch")
	quit(0)
func _fail(message: String) -> void:
	printerr("TASK052 HERO CLASSES FAIL: "+message)
	quit(1)
