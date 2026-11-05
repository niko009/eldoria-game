extends SceneTree

const STATE := preload("res://ui/mock_game_ui_state.gd")
const HUD := preload("res://ui/GameHud.tscn")
const PANEL := preload("res://ui/CraftingPanel.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = STATE.new()
	state.set_stock("empty")
	state.near_campfire = false
	var hud = HUD.instantiate()
	hud.state = state
	hud.show_touch_controls = false
	root.add_child(hud)
	var workshop = PANEL.instantiate()
	workshop.state = state
	root.add_child(workshop)
	await process_frame
	var opening_order: Array[String] = state.recipes_ready_first()
	if not _verify(state, hud, workshop, 0, []):
		return

	# Four recipes have sufficient materials: axe, repair kit, spear, arrow.
	state.inventory = {"wood":3, "stone":2, "herb":0, "axe":0, "spear":0, "arrow":0}
	state.changed.emit()
	await process_frame
	if not _verify(state, hud, workshop, 4, ["axe", "repair_kit", "spear", "arrow"]):
		return
	if state.near_campfire:
		_fail("badge should reflect collected ingredients even when away from camp")
		return

	# Owning a unique weapon removes it from the available recipes.
	state.inventory["spear"] = 1
	state.changed.emit()
	await process_frame
	if not _verify(state, hud, workshop, 3, ["axe", "repair_kit", "arrow"]):
		return

	# Remote inventory snapshots can invalidate every ready recipe.
	state.inventory = {"wood":0, "stone":2, "herb":0, "axe":0, "spear":1, "arrow":0}
	state.changed.emit()
	await process_frame
	if not _verify(state, hud, workshop, 0, []):
		return

	# Stack caps must not count already-full consumables.
	state.inventory = {"wood":1, "stone":1, "arrow":40, "axe":1, "spear":1}
	state.changed.emit()
	await process_frame
	if not _verify(state, hud, workshop, 0, []):
		return

	print("TASK046 CRAFTING SORT/BADGE PASS available-first, live count, full stacks, depleted materials")
	quit(0)

func _verify(state: RefCounted, hud: Control, workshop: Control, expected_count: int, expected_first: Array[String]) -> bool:
	if state.ready_recipe_count() != expected_count:
		_fail("ready recipe count mismatch: %d vs %d" % [state.ready_recipe_count(), expected_count])
		return false
	var badge: Control = hud.get_node("QuickMenu/Menu_craft/CraftReadyBadge")
	var label: Label = badge.get_node("Count")
	if badge.visible != (expected_count > 0):
		_fail("badge visibility mismatch")
		return false
	if label.text != str(expected_count):
		_fail("badge text mismatch: "+label.text)
		return false
	var ordered: Array[String] = state.recipes_ready_first()
	for index in expected_first.size():
		if ordered[index] != expected_first[index]:
			_fail("wrong ready recipe order: "+str(ordered))
			return false
	var names: Array[String] = []
	for node in workshop.get_node("RecipeGrid").get_children():
		names.append(str(node.name).trim_prefix("RecipeCard_"))
	# During an open crafting session the original order must stay fixed,
	# even when a recipe becomes unavailable after crafting.
	if names != workshop.recipe_order:
		_fail("UI reordered recipes after inventory change: "+str(names))
		return false
	return true

func _fail(reason: String) -> void:
	printerr("TASK046 CRAFTING SORT/BADGE FAIL: "+reason)
	quit(1)