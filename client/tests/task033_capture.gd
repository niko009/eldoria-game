extends SceneTree
# TASK-033 reproducible visual approval image from real KayKit + procedural
# stone axe meshes (no AI screenshot). Isolated studio; no public connection.
const ACTOR := preload("res://animated_actor.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var floor := MeshInstance3D.new()
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(14, 8)
	floor.mesh = floor_mesh
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("57756b")
	floor_material.roughness = 0.94
	floor.material_override = floor_material
	stage.add_child(floor)

	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("91b4ad")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d6e9dc")
	environment.ambient_light_energy = 0.68
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	stage.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,-26,-12)
	sun.light_energy = 1.05
	sun.light_color = Color("fff2d4")
	stage.add_child(sun)

	for choice in 3:
		var actor: Node3D = ACTOR.new()
		actor.configure(choice + 1, false, choice)
		actor.name = ["Knight","Rogue","Mage"][choice]
		actor.position = Vector3((choice-1)*2.1, 1, 0)
		stage.add_child(actor)
		actor.set_axe_equipped(choice != 0)
		actor.rotation.y = 0.12 if choice == 2 else 0
		if choice == 1:
			actor.melee_attack()
	var camera := Camera3D.new()
	camera.position = Vector3(0, 2.65, 8.3)
	camera.fov = 39
	stage.add_child(camera)
	camera.look_at(Vector3(0, 1.00, 0))
	camera.current = true
	for i in range(10):
		await process_frame
	var out := "/tmp/eldoria-task033-actors.png"
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--screenshot" and i+1 < args.size():
			out = args[i+1]
	var image := root.get_texture().get_image()
	var err := image.save_png(out)
	print("TASK033 CHARACTER SCREENSHOT ", image.get_size(), " code=", err, " path=", out)
	quit(int(err))
