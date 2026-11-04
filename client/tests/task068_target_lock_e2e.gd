extends SceneTree
const GAME := preload("res://Main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node3D = GAME.instantiate()
	game.selected_avatar = 1
	root.add_child(game)
	await process_frame
	game._host()
	game.set_physics_process(false)
	var id: int = game.own_id
	game.player_choices[id] = 1
	game.player_inventories[id] = game._empty_inventory()
	var world: Node3D = game.get_node("Eldoria_Forest")
	var at := Vector3(0,world.height_at(0,0)+1,0)
	game.players[id].position = at
	game.wolf_alive = false
	game.wolf_alive = true
	game.wolf_health = 60
	game.wolf_position = at+Vector3(1.1,0,0)
	game.pack_wolves.clear()
	for creature_id in game.passive_creatures:
		game.passive_creatures[creature_id]["alive"] = false
	var one: Dictionary = game.passive_creatures[1]
	var two: Dictionary = game.passive_creatures[2]
	one["alive"] = true
	two["alive"] = true
	one["hp"] = 24
	two["hp"] = 24
	one["position"] = at+Vector3(2.2,0,0)
	two["position"] = at+Vector3(2.7,0,0)
	game.passive_snapshot(1,"rabbit",one["position"],24,true,Vector3.ZERO)
	game.passive_snapshot(2,"rabbit",two["position"],24,true,Vector3.ZERO)
	game._select_combat_target(102)
	if game.selected_target_id != 102 or game.selected_target_marker == null or not game.selected_target_marker.visible:
		_fail("selection ring missing")
		return
	if not game.selected_target_marker.get_node("EnemyName").text.contains("Кролик"):
		_fail("selected target name missing")
		return
	if not game._attack_on_server(id,Vector3.ZERO,102):
		_fail("locked melee attack rejected")
		return
	if int(two["hp"]) != 4 or int(one["hp"]) != 24 or game.wolf_health != 60:
		_fail("melee hit nearest instead of selected target")
		return
	game.last_attack_at.erase(id)
	if game._attack_on_server(id,Vector3.ZERO,999) or int(one["hp"]) != 24:
		_fail("invalid target id fell back to auto hit")
		return
	game._refresh_selected_target()
	if not game.selected_target_marker.get_node("EnemyName").text.contains("4/24"):
		_fail("selected HP marker did not update")
		return
	two["position"] = at+Vector3(15,0,0)
	game.last_attack_at.erase(id)
	if game._attack_on_server(id,Vector3.ZERO,102) or int(two["hp"]) != 4:
		_fail("locked melee bypassed range")
		return
	# Server overrides the camera direction for a chosen ranged target.
	one["position"] = at+Vector3(5,0,0)
	one["hp"] = 24
	game.equipped_combat[id] = "bow"
	game.player_inventories[id]["bow"] = 1
	game.player_inventories[id]["arrow"] = 3
	game.last_attack_at.erase(id)
	if not game._attack_on_server(id,Vector3.FORWARD,101):
		_fail("locked arrow did not fire")
		return
	if int(one["hp"]) >= 24 or int(two["hp"]) != 4 or int(game.player_inventories[id]["arrow"]) != 2 or game.wolf_health != 60:
		_fail("locked arrow hit wrong target or consumed wrong amount")
		return
	var bow_hp := int(one["hp"])
	one["position"] = at+Vector3(30,0,0)
	game.last_attack_at.erase(id)
	if game._attack_on_server(id,Vector3.FORWARD,101) or int(game.player_inventories[id]["arrow"]) != 2 or int(one["hp"]) != bow_hp:
		_fail("out-of-range locked shot consumed ammunition or dealt damage")
		return
	# Mage targets the selected enemy without being allowed to ignore mana.
	game.player_choices[id] = 2
	game.equipped_combat[id] = "unarmed"
	game.hero_mana[id] = 60.0
	one["position"] = at+Vector3(5,0,0)
	one["hp"] = 24
	game.last_attack_at.erase(id)
	if not game._mage_attack_on_server(id,Vector3.FORWARD,0,101) or int(one["hp"]) != 6 or int(game.hero_mana[id]) != 46:
		_fail("locked mage spell failed to damage selected enemy")
		return
	game.last_attack_at.erase(id)
	game.hero_mana[id] = 0.0
	if game._mage_attack_on_server(id,Vector3.FORWARD,0,101) or int(one["hp"]) != 6:
		_fail("target selection bypassed mana validation")
		return
	game._select_combat_target(101)
	one["hp"] = 0
	one["alive"] = false
	game._refresh_selected_target()
	if game.selected_target_id != 0 or game.selected_target_marker.visible:
		_fail("dead target did not clear selection")
		return
	game.pack_wolves[1] = {"position":at+Vector3(2.5,0,0),"hp":60,"alive":true,"direction":Vector3.ZERO,"last_hit":0}
	game.player_choices[id] = 1
	game.equipped_combat[id] = "unarmed"
	game.last_attack_at.erase(id)
	if not game._attack_on_server(id,Vector3.ZERO,1) or int(game.pack_wolves[1]["hp"]) != 40 or game.wolf_health != 60:
		_fail("selection of raid wolf failed or hit the lone wolf")
		return
	game.pack_wolves.clear()
	game.wolf_alive = false
	# Selecting by tap/right click uses the projected world position, and Tab
	# (mobile target button) cycles candidates without changing the camera aim.
	one["hp"] = 24
	one["alive"] = true
	one["position"] = at+Vector3(4.0,0,0)
	two["position"] = at+Vector3(25,0,0)
	game.camera.position = at+Vector3(0,5,10)
	game.camera.look_at(one["position"]+Vector3.UP*0.5)
	var touch_at: Vector2 = game.camera.unproject_position(one["position"]+Vector3.UP*0.35)
	game._select_target_at_screen(touch_at)
	if game.selected_target_id != 101:
		_fail("screen tap did not select projected mob")
		return
	game._cycle_combat_target()
	if game.selected_target_id != 0:
		_fail("target cycle did not clear the last target")
		return
	game._cycle_combat_target()
	if game.selected_target_id != 101:
		_fail("target cycle did not pick visible mob")
		return
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	touch.position = touch_at
	game._unhandled_input(touch)
	if game.selected_target_id != 0:
		_fail("tapping selected mob did not deselect it")
		return
	print("TASK068 TARGET LOCK PASS melee, archery, magic, marker, ranges, invalid ID and clear-on-death")
	quit(0)

func _fail(problem: String) -> void:
	printerr("TASK068 TARGET LOCK FAIL: "+problem)
	quit(1)
