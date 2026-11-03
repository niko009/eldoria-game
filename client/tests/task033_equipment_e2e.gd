extends SceneTree
# TASK-033 — imported KayKit sockets, tool state, remount on avatar switch,
# server-authoritative equip visuals and animation compatibility.
const ACTOR := preload("res://animated_actor.gd")
const MAIN := preload("res://Main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for choice in 3:
		var actor: Node3D = ACTOR.new()
		actor.configure(choice+1, false, choice)
		root.add_child(actor)
		if actor.axe_visual == null or not is_instance_valid(actor.axe_visual):
			_fail("axe absent from avatar %d" % choice)
			return
		if not actor.axe_visual.get_parent() is BoneAttachment3D:
			_fail("equipment is not attached to skinned right hand")
			return
		if actor.axe_visual.get_parent().name != "handslot_r":
			_fail("wrong equipment hand")
			return
		if actor.axe_visual.visible:
			_fail("actor spawned with an owned but unequipped tool")
			return
		actor.set_axe_equipped(true)
		if not actor.axe_visual.visible:
			_fail("axe not visible on equip")
			return
		actor.set_motion(Vector3(4, 0, 0))
		actor.gather("wood")
		if actor.current_clip != "1H_Melee_Attack_Chop" or not actor.axe_visual.visible:
			_fail("axe did not remain attached during chop animation")
			return
		var updated := (choice + 1) % 3
		actor.set_avatar(updated)
		await process_frame
		if actor.axe_visual == null or not is_instance_valid(actor.axe_visual) or not actor.axe_visual.visible:
			_fail("axe lost after hero swap %d" % choice)
			return
		actor.set_axe_equipped(false)
		if actor.axe_visual.visible:
			_fail("unequip did not hide axe")
			return
		actor.queue_free()

	# Dedicated server never spawns a visual prop, even if equipped.
	var dedicated: Node3D = ACTOR.new()
	dedicated.configure(40, true, 0)
	root.add_child(dedicated)
	dedicated.set_axe_equipped(true)
	if dedicated.visual != null or dedicated.axe_visual != null:
		_fail("dedicated server allocated 3D weapon meshes")
		return
	dedicated.queue_free()

	var game: Node3D = MAIN.instantiate()
	root.add_child(game)
	await process_frame
	game._host()
	var id: int = game.own_id
	if id == 0:
		_fail("local server failed to start")
		return
	if game.players[id].axe_equipped:
		_fail("fresh actor must be bare-handed")
		return
	if game._set_axe_equipped_on_server(id, true):
		_fail("server equipped an axe that isn't owned")
		return
	game.player_inventories[id] = {"wood": 0, "stone": 0, "herb": 0, "axe": 1}
	if not game._set_axe_equipped_on_server(id, true):
		_fail("owned tool cannot be equipped")
		return
	if not game.players[id].axe_equipped or not game.players[id].axe_visual.visible:
		_fail("server ACK didn't update local hero visual")
		return
	game._set_axe_equipped_on_server(id, false)
	if game.players[id].axe_visual.visible:
		_fail("server unequip didn't hide local visual")
		return
	# On real clients this same authority RPC targets a remote actor.
	game._spawn(532, Vector3(4, 1, 0), 2)
	game.axe_visual_snapshot(532, true)
	if not game.players[532].axe_visual.visible:
		_fail("remote actor visual equipment replication failed")
		return
	game.axe_visual_snapshot(532, false)
	if game.players[532].axe_visual.visible:
		_fail("remote actor unequip replication failed")
		return
	game._disconnect()
	print("TASK033 EQUIPMENT PASS 3 avatars, hand sockets, animation, avatar swap, dedicated, server-owned and remote replication")
	quit(0)

func _fail(message: String) -> void:
	printerr("TASK033 EQUIPMENT FAIL " + message)
	quit(1)
