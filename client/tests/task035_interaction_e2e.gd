extends SceneTree
# TASK-035: effects and animation only after confirmed gather; no server
# authority, persistence or gameplay changes.
const GAME := preload("res://Main.tscn")
const ACTOR := preload("res://animated_actor.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	var world: Node3D = game.get_node("Eldoria_Forest")
	var visuals: Node3D = game.harvest_visuals
	visuals.set_sound_enabled(false)
	for choice in range(3):
		var actor: Node3D = ACTOR.new()
		actor.configure(choice + 301, false, choice)
		actor.position = Vector3(0, 1, -1)
		root.add_child(actor)
		actor.face_interaction(Vector3(3, 0, -1))
		if absf(actor.rotation.y - PI/2.0) > 0.01:
			_fail("actor did not face the interaction target")
			return
		actor.gather("wood")
		if actor.current_clip != "PickUp":
			_fail("wood gathering without axe must use hands, avatar %d" % choice)
			return
		actor.set_axe_equipped(true)
		actor.gather("wood")
		if actor.current_clip != "1H_Melee_Attack_Chop":
			_fail("equipped axe must use chop animation, avatar %d" % choice)
			return
		actor.gather("stone")
		if actor.current_clip != "PickUp":
			_fail("stone gathering with no pickaxe cannot chop")
			return
		actor.queue_free()
	var server_actor: Node3D = ACTOR.new()
	server_actor.configure(909, true, 0)
	root.add_child(server_actor)
	server_actor.face_interaction(Vector3(3, 0, 3))
	server_actor.gather("wood")
	if server_actor.visual != null:
		_fail("headless actor spawned visuals")
		return
	server_actor.queue_free()
	# A rejected/invalid resource is not permitted to fabricate reward text.
	if visuals.play_pickup("not_a_resource", Vector3.ZERO) or visuals.resource_feedback_count() != 0:
		_fail("invalid gather created a popup")
		return
	# Pool limits cap both particles and 3D reward text.
	for kind in ["wood", "stone", "herb", "wood", "stone"]:
		if not visuals.play_pickup(kind, Vector3.ZERO):
			_fail("five successful pickups should fit within the VFX budget")
			return
	if visuals.resource_feedback_count() != 5 or visuals.burst_count() != 5:
		_fail("pickup effects exceeded or underfilled bounded pool")
		return
	if visuals.play_pickup("herb", Vector3.ZERO):
		_fail("sixth burst should be rejected, not spawn more draw calls")
		return
	var first: Node3D = visuals._resource_feedback[0]
	var label := first.get_node_or_null("RewardLabel") as Label3D
	if label == null or label.text != "WOOD" or label.billboard != BaseMaterial3D.BILLBOARD_ENABLED:
		_fail("actual camera-facing reward label missing")
		return
	if label.text.contains("+2") or label.text.contains("+1"):
		_fail("visual feedback invented a resource amount not present in RPC")
		return
	await create_timer(1.12).timeout
	if visuals.resource_feedback_count() != 0 or visuals.burst_count() != 0:
		_fail("short-lived interaction visuals were not cleaned up")
		return
	visuals.play_pickup("stone", Vector3.ZERO)
	visuals.clear_effects()
	if visuals.resource_feedback_count() != 0 or visuals.burst_count() != 0:
		_fail("disconnect/clear left HUD markers or particles in world")
		return
	# Network-facing path: local-only call with a valid resource entry.
	game._host()
	var grass: Dictionary = {}
	for entry in world.resources:
		if entry["kind"] == "herb":
			grass = entry
			break
	if grass.is_empty():
		_fail("test world has no herb")
		return
	game.players[game.own_id].set_axe_equipped(false)
	game._gather_effect_local(game.own_id, "herb", int(grass["id"]), 1, Vector3.ZERO)
	if game.players[game.own_id].current_clip != "PickUp":
		_fail("accepted gather event didn't trigger the expected animation")
		return
	if visuals.resource_feedback_count() != 1:
		_fail("accepted gather event did not create visible resource text")
		return
	game._disconnect()
	if visuals.resource_feedback_count() != 0:
		_fail("disconnect left resource labels active")
		return
	print("TASK035 INTERACTION OPENGL PASS avatars facing, tool-aware clips, camera labels, VFX limits, cleanup, accepted events")
	quit(0)

func _fail(message: String) -> void:
	printerr("TASK035 INTERACTION OPENGL FAIL " + message)
	quit(1)
