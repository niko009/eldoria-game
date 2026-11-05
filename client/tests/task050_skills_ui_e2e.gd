extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(800,360)
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	var ui = game.live_ui
	if ui == null:
		_fail("live UI not created")
		return
	ui.size = Vector2(800,360)
	ui._layout()
	ui.set_skills({"archery":25,"spear":100,"defense":400,"magic":25})
	ui.hud.top_controls["skills"].pressed.emit()
	await process_frame
	await process_frame
	if ui.active_panel != "skills" or ui.panel_title.text != "НАВЫКИ" or ui.saved_skills["spear"] != 100:
		_fail("skills tab did not open or show updated XP")
		return
	var panel: VBoxContainer = ui.current_panel
	for key in ["archery","spear","defense","magic"]:
		var row: PanelContainer = panel.get_node("Skill_"+key)
		var gauge: ProgressBar = row.get_node("Details/XpProgress")
		if row == null or gauge == null or gauge.max_value < 1:
			_fail("skill progress bar missing: "+key)
			return
	if not panel.get_node("Skill_archery/Details/Level").text.contains("УРОВЕНЬ 2"):
		_fail("archery level display incorrect")
		return
	if not panel.get_node("Skill_defense/Details/Bonus").text.contains("60%"):
		_fail("shield effect label missing")
		return
	if not panel.get_node("Skill_magic/Details/Level").text.contains("УРОВЕНЬ 2"):
		_fail("magic XP level missing")
		return
	ui.set_skills({"archery":400,"spear":100,"defense":400})
	await process_frame
	if not ui.current_panel.get_node("Skill_archery/Details/Bonus").text.contains("+8"):
		_fail("live skill snapshot not reflected in open panel")
		return
	for tab in ui.tabs.get_children():
		if tab.get_global_rect().end.x > ui.dialog.get_global_rect().end.x + 1.0:
			_fail("tabs clipped on Android-size landscape viewport")
			return
	ui._close()
	if ui.active_panel != "" or not ui.hud.top_controls.has("skills"):
		_fail("skills menu cannot close or access from HUD")
		return
	print("TASK050 SKILLS UI PASS Android-size menu, 4 gauges including magic, live updates")
	quit(0)
func _fail(message: String) -> void:
	printerr("TASK050 SKILLS UI FAIL: "+message)
	quit(1)
