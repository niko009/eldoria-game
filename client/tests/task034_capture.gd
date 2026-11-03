extends SceneTree
# TASK-034: reproducible screenshot of the real Godot forest with real
# building meshes. Uses local synthetic building records; no WSS or production.
const MAIN := preload("res://Main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node3D = MAIN.instantiate()
	root.add_child(game)
	await process_frame
	var forest: Node3D = game.get_node("Eldoria_Forest")
	var camp_x := 0.0
	var camp_z := -4.0
	var tent_x := -4.0
	var tent_z := 0.0
	game._place_building(1001, {"kind":"campfire","x":camp_x,"z":camp_z})
	game._place_building(1002, {"kind":"tent","x":tent_x,"z":tent_z})
	game._spawn(3, Vector3(2,forest.height_at(2,0) + 1,0), 0)
	# Center the structures instead of the scene's distant skyline.
	game.camera.position = Vector3(-1.0, 3.6, 6.3)
	game.camera.fov = 57
	game.camera.look_at(Vector3(-1.8, 1.02, -1.4), Vector3.UP)
	if game.player_ui != null:
		game.player_ui.visible = false
	var options := OS.get_cmdline_user_args()
	if options.has("--low"):
		game.graphics_quality = 0
		for node in game.building_nodes.values():
			node.set_visual_detail(false)
		game.get_node("Eldoria_Forest").apply_detail_quality(false)
	var output := "/tmp/eldoria-034-building.png"
	for idx in options.size() - 1:
		if options[idx] == "--screenshot":
			output = options[idx + 1]
	for frame in 16:
		await process_frame
	var image := root.get_texture().get_image()
	var err := image.save_png(output)
	if err != OK:
		printerr("TASK034 CAPTURE FAILED %s" % err)
		quit(1)
		return
	print("TASK034 CAPTURE PASS ", image.get_size(), " ", output)
	quit(0)
