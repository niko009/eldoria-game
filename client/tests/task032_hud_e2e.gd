extends SceneTree
# TASK-032: verify the live HUD geometry, readability and behaviour on portrait-
# derived landscape aspect ratios without connecting to production.
const MAIN := preload("res://Main.tscn")
const DEVICES := [Vector2i(1280, 720), Vector2i(1280, 576), Vector2i(800, 360), Vector2i(640, 360)]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node3D = MAIN.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var ui: Control = scene.live_ui
	if ui == null:
		_fail("no Live UI")
		return
	ui.set_inventory({"wood": 14, "stone": 8, "herb": 7, "axe": 1})
	ui.set_health(73, 100)
	ui.set_status("Connected, ID 123")
	ui.state.select_item("axe")
	var hud: EldoriaGameHud = ui.hud
	for display in DEVICES:
		root.size = display
		for frame in range(3):
			await process_frame
		hud._layout()
		var left: Rect2 = hud.status_panel.get_global_rect()
		var right: Rect2 = hud.top_actions.get_global_rect()
		var resources: Rect2 = hud.resources_panel.get_global_rect()
		var hot: Rect2 = hud.hotbar.get_global_rect()
		var stick: Rect2 = hud.joystick.get_global_rect()
		if left.intersects(right) or left.intersects(resources) or right.intersects(resources):
			_fail("top HUD overlaps for " + str(display))
			return
		if hot.intersects(stick):
			_fail("equipment overlaps joystick " + str(display))
			return
		for id in hud.action_controls:
			var button: Button = hud.action_controls[id]
			var r: Rect2 = button.get_global_rect()
			if r.intersects(hot):
				_fail("action %s collides with hotbar at %s" % [id, display])
				return
			if r.intersects(right):
				_fail("action %s collides with top menu at %s" % [id, display])
				return
			if r.intersects(left):
				_fail("action %s collides with player panel at %s" % [id, display])
				return
		for action in hud.top_controls:
			if hud.top_controls[action].text != "":
				_fail("menu uses obsolete text buttons")
				return
		if hud.resource_counts["wood"].text != "14" or hud.health_detail.text != "73/100":
			_fail("state not reflected in compact HUD")
			return
		if hud.action_controls.size() != 4:
			_fail("compact cluster should have four independent touch actions")
			return
		print("TASK032 LAYOUT PASS ", display, " logical_viewport=", hud.size)

	# User screenshot: the old client reports 'Please update', not online HP.
	# This warning must remain actionable instead of disappearing inside tiny status text.
	ui.set_status("Please update Eldoria client to v0.5.7.")
	if not hud.warning_detail.visible or not hud.warning_detail.text.contains("обновление"):
		_fail("outdated client warning lost")
		return
	ui.set_status("Connected, ID 123")
	if hud.warning_detail.visible:
		_fail("obsolete warning not cleared")
		return
	var calls: Array[String] = []
	hud.action_requested.connect(func(kind: String) -> void: calls.append(kind))
	hud._touch_action("attack")
	hud._touch_action("gather")
	hud._touch_action("jump")
	hud._touch_action("sprint")
	if calls != ["attack", "gather", "jump", "sprint"]:
		_fail("mobile action bindings changed " + str(calls))
		return
	ui._open("settings")
	await process_frame
	if not ui.overlay.visible or ui.active_panel != "settings":
		_fail("settings quick menu no longer works")
		return
	ui._close()
	print("TASK032 MOBILE HUD PASS status, equipment, resources, touch, menu")
	scene.queue_free()
	quit(0)

func _fail(message: String) -> void:
	printerr("TASK032 MOBILE HUD FAIL " + message)
	quit(1)
