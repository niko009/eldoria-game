extends SceneTree
# Render the actual Main scene + live HUD, with synthetic UI data only for screenshots.
# Run under Xvfb and OpenGL; no connection to the production game server.
const MAIN := preload("res://Main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node3D = MAIN.instantiate()
	root.add_child(scene)
	for i in range(18):
		await process_frame
	if scene.live_ui == null:
		push_error("No live UI")
		quit(2)
		return
	scene.live_ui.set_inventory({"wood": 26, "stone": 8, "herb": 14, "axe": 1})
	scene.live_ui.set_health(86, 100)
	scene.live_ui.set_status("Connected, ID 123")
	scene.live_ui.set_avatar(0)
	scene.live_ui.state.select_item("axe")
	scene.live_ui.hud.show_touch_controls = true
	scene.live_ui.hud.refresh()
	var args := OS.get_cmdline_user_args()
	if args.has("--modal"):
		var index := args.find("--modal")
		if index + 1 < args.size():
			scene.live_ui._open(args[index + 1])
	for i in range(16):
		await process_frame
	var out := "/tmp/eldoria-task032-screen.png"
	for i in range(args.size()):
		if args[i] == "--screenshot" and i+1 < args.size():
			out = args[i+1]
	var img := root.get_texture().get_image()
	var code := img.save_png(out)
	print("TASK032 SCREEN ", img.get_size(), " result=", code, " file=", out)
	scene.queue_free()
	quit(int(code))
