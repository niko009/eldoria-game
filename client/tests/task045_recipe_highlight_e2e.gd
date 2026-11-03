extends SceneTree
const PANEL := preload("res://ui/CraftingPanel.tscn")
const STATE := preload("res://ui/mock_game_ui_state.gd")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var s = STATE.new()
	s.set_stock("empty")
	var panel = PANEL.instantiate()
	panel.state = s
	root.add_child(panel)
	await process_frame
	await create_timer(0.05).timeout
	if _is_ready(panel,"spear"):
		_fail("empty inventory highlighted spear")
		return
	var inv: Dictionary = s.inventory.duplicate()
	inv["wood"] = 3
	inv["stone"] = 2
	s.inventory = inv
	s.changed.emit()
	await process_frame
	await create_timer(0.05).timeout
	await process_frame
	await create_timer(0.05).timeout
	if not _is_ready(panel,"spear"):
		_fail("affordable spear not highlighted")
		return
	inv = s.inventory.duplicate()
	inv["spear"] = 1
	s.inventory = inv
	s.changed.emit()
	await process_frame
	await create_timer(0.05).timeout
	await process_frame
	await create_timer(0.05).timeout
	if _is_ready(panel,"spear"):
		_fail("owned unique spear highlighted")
		return
	print("TASK045 RECIPE HIGHLIGHT PASS")
	quit(0)
func _is_ready(panel: Node, recipe: String) -> bool:
	var card = panel.get_node_or_null("RecipeCard_"+recipe)
	if card == null:
		return false
	var column = card.get_child(0)
	print("CHECK ",recipe," children=",panel.get_child_count()," label=",column.get_child(0).text," wood=",panel.state.amount("wood")," stone=",panel.state.amount("stone"))
	return column.get_child(0).text.begins_with("● МОЖНО СОЗДАТЬ")
func _fail(reason: String) -> void:
	printerr("TASK045 RECIPE HIGHLIGHT FAIL: "+reason)
	quit(1)
