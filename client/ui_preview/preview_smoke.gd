extends SceneTree

const PreviewScene = preload("res://ui_preview/UiPreview.tscn")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var preview := PreviewScene.instantiate()
	root.add_child(preview)
	await process_frame
	var failures := 0
	for viewport_size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(800, 360)]:
		root.size = viewport_size
		preview.size = viewport_size
		await process_frame
		preview._layout()
		preview.hud._layout()
		await process_frame
		if preview.preview_tools.position.x + preview.preview_tools.size.x > viewport_size.x or preview.preview_tools.position.y + preview.preview_tools.size.y > viewport_size.y:
			push_error("Preview controls exceed viewport %s: pos %s size %s min %s cols %d" % [viewport_size, preview.preview_tools.position, preview.preview_tools.size, preview.preview_tools.get_combined_minimum_size(), preview.preview_tools.columns])
			failures += 1
		if preview.window_panel.size.x > viewport_size.x or preview.window_panel.size.y > viewport_size.y:
			push_error("Panel exceeds viewport %s: actual %s min %s scroll %s column %s" % [viewport_size, preview.window_panel.size, preview.window_panel.get_combined_minimum_size(), preview.content_scroll.get_combined_minimum_size(), preview.window_panel.get_child(0).get_combined_minimum_size()])
			failures += 1
		if preview.hud.hotbar.position.x < 0 or preview.hud.hotbar.position.x + preview.hud.hotbar.size.x > viewport_size.x:
			push_error("Hotbar exceeds viewport %s" % viewport_size)
			failures += 1
	preview._open("inventory")
	await process_frame
	if preview.content_scroll.get_child_count() != 1:
		push_error("Inventory did not open")
		failures += 1
	preview.state.set_stock("plenty")
	preview.state.select_item("axe")
	if preview.state.selected_item != "axe":
		push_error("Item selection failed")
		failures += 1
	preview._open("build")
	await process_frame
	var build_panel: EldoriaBuildingPanel = preview.content_scroll.get_child(0)
	if build_panel.selected != "campfire" or not preview.state.can_afford(preview.state.BUILDINGS["campfire"]["cost"]):
		push_error("Building panel state is incorrect")
		failures += 1
	preview.state.set_stock("scarce")
	if preview.state.can_afford(preview.state.BUILDINGS["campfire"]["cost"]):
		push_error("Scarce resources must disable building")
		failures += 1
	preview._open("craft")
	await process_frame
	if preview.content_scroll.get_child(0) is not EldoriaCraftingPanel:
		push_error("Crafting panel did not open")
		failures += 1
	preview._close()
	await create_timer(0.2).timeout
	if preview.overlay.visible:
		push_error("Panel did not close")
		failures += 1
	print("TASK-021A smoke: %s" % ("PASS" if failures == 0 else "%d FAILURES" % failures))
	quit(0 if failures == 0 else 1)
