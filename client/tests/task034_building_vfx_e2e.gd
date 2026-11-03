extends SceneTree
# TASK-034: actual OpenGL/Xvfb validation of visible meshes, mobile LOD,
# build-completion effects, preview feedback and no save-side effects.
const GAME := preload("res://Main.tscn")
const BUILD := preload("res://building_object.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	var world: Node3D = game.get_node("Eldoria_Forest")
	game.harvest_visuals.set_sound_enabled(false)
	game._place_building(710, {"kind": "campfire", "x": 0, "z": -4})
	game._place_building(711, {"kind": "tent", "x": -4, "z": 0})
	var camp: Node3D = game.building_nodes[710]
	var tent: Node3D = game.building_nodes[711]
	if not _has(camp, "CookingPot") or not _has(camp, "CookingPotLid") or not _has(tent, "CanvasEmbroideries"):
		_fail("decorative camp/tent details were not constructed")
		return
	if not _has(tent, "SupplyChest") or not _has(tent, "Bedroll"):
		_fail("tent interior missing")
		return
	if camp.get_child_count() < 20 or tent.get_child_count() < 11:
		_fail("buildings lost visible mesh components")
		return
	if game.placed_buildings.size() != 2 or BUILD.RADII["tent"] != 2.0 or BUILD.COSTS["campfire"]["stone"] != 2:
		_fail("new visuals changed authoritative world geometry/costs")
		return
	var models := [camp, tent]
	for building in models:
		building.set_visual_detail(false)
		if building.kind == "tent" and building.get_node("SupplyChest").visible:
			_fail("Android LOW failed to cull optional chest")
			return
		if building.kind == "campfire" and building.get_node("CookingPot").visible:
			_fail("Android LOW failed to cull optional pot")
			return
		building.set_visual_detail(true)
		if building.kind == "tent" and not building.get_node("SupplyChest").visible:
			_fail("HIGH failed to show tent props")
			return
		if building.kind == "campfire" and not building.get_node("CookingPot").visible:
			_fail("HIGH failed to show camp props")
			return
	var ghost: Node3D = BUILD.new()
	ghost.is_preview = true
	ghost.setup(712, "tent", Vector3(-8, world.height_at(-8, 0), 0))
	game.add_child(ghost)
	ghost.set_visual_detail(false)
	ghost.set_preview_valid(false)
	for node in ghost.get_children():
		if node is MeshInstance3D and node.material_override != ghost._ghost_material:
			_fail("placement preview has incorrect materials")
			return
	ghost.set_preview_valid(true)
	if ghost._ghost_material.albedo_color.g < 0.8:
		_fail("valid placement preview not green")
		return
	ghost.queue_free()
	var vfx: Node3D = game.harvest_visuals
	var spot := Vector3(0, world.height_at(0,-4), -4)
	for i in 4:
		if not vfx.play_build_effect("campfire" if i % 2 == 0 else "tent", spot):
			_fail("cannot start bounded construction effect")
			return
	if vfx.building_burst_count() != 4 or vfx.play_build_effect("tent", spot):
		_fail("build effect did not enforce the four-burst limit")
		return
	await create_timer(1.40).timeout
	if vfx.building_burst_count() != 0:
		_fail("transient build effects did not clean up")
		return
	# Restoring saved buildings calls only _place_building, never play_build_effect.
	game._clear_buildings()
	game._place_building(710, {"kind": "campfire", "x": 0, "z": -4})
	if vfx.building_burst_count() != 0:
		_fail("restoring buildings triggers false construction effects")
		return
	game.building_created(711, {"kind":"tent","x": -4, "z": 0})
	if vfx.building_burst_count() != 1:
		_fail("newly replicated building did not show visual feedback")
		return
	game._disconnect()
	if vfx.building_burst_count() != 0:
		_fail("disconnect did not clean up transient visual effects")
		return
	print("TASK034 BUILDING OPENGL PASS tent/camp meshes, LOW/HIGH, ghost, bounded build VFX, rollback-safe restoration")
	quit(0)

func _has(building: Node3D, name: String) -> bool:
	return building.get_node_or_null(name) != null

func _fail(reason: String) -> void:
	printerr("TASK034 BUILDING OPENGL FAIL " + reason)
	quit(1)
