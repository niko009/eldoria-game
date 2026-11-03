extends SceneTree
const GAME := preload("res://Main.tscn")
const HASH := "49bcd943ac35d6028c9f138bb1583e6a6fc0e3e879349006eafb9f2a6ea0c639"
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	game._host()
	if game.own_id <= 0:
		_fail("host unavailable")
		return
	var restored := OS.get_cmdline_user_args().has("--restored")
	if restored:
		if not game.persistent_profiles.has(HASH):
			_fail("persistent identity absent")
			return
		var profile: Dictionary = game.persistent_profiles[HASH]
		if int(profile["skills"].get("archery",-1)) != 31 or int(profile["skills"].get("spear",-1)) != 3 or int(profile["skills"].get("defense",-1)) != 1:
			_fail("skill xp did not survive restart: "+str(profile.get("skills")))
			return
		if int(profile["inventory"].get("bow",0)) != 1 or int(profile["inventory"].get("arrow",0)) != 8 or int(profile["inventory"].get("shield",0)) != 1:
			_fail("expanded inventory did not survive restart")
			return
		print("TASK049 SKILLS RESTORED PASS skills + expanded inventory")
		quit(0)
		return
	var id: int = game.own_id
	var inv: Dictionary = game._empty_inventory()
	inv["bow"] = 1
	inv["arrow"] = 8
	inv["shield"] = 1
	game.player_inventories[id] = inv
	game.player_identity_keys[id] = HASH
	game.player_skills[id] = game._empty_skills()
	game.persistent_profiles[HASH] = {"avatar":0,"inventory":inv.duplicate(true),"skills":game._empty_skills()}
	if not game._award_skill_xp(id,"archery",31) or not game._award_skill_xp(id,"spear",3):
		_fail("xp award/save refused")
		return
	if not game._equip_combat_on_server(id,"shield"):
		_fail("shield equip refused")
		return
	game.wolf_alive = true
	if not game._damage_player_on_server(id,20) or int(game.player_skills[id]["defense"]) != 1:
		_fail("shield skill xp refused")
		return
	if game._award_skill_xp(id,"fake_skill",100):
		_fail("invalid skill accepted")
		return
	if not game._save_world_state():
		_fail("profile save failed")
		return
	print("TASK049 SKILLS INITIAL PASS xp + inventory + shield credit")
	quit(0)
func _fail(why: String) -> void:
	printerr("TASK049 SKILLS FAIL: "+why)
	quit(1)
