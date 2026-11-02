extends Control

const Style = preload("res://ui/ui_style.gd")
const State = preload("res://ui/mock_game_ui_state.gd")
const HudScene = preload("res://ui/GameHud.tscn")
const InventoryScene = preload("res://ui/InventoryPanel.tscn")
const BuildingScene = preload("res://ui/BuildingPanel.tscn")
const CraftingScene = preload("res://ui/CraftingPanel.tscn")

var state: MockGameUiState
var hud: EldoriaGameHud
var preview_tools: GridContainer
var overlay: ColorRect
var window_panel: PanelContainer
var content_scroll: ScrollContainer
var panel_title: Label
var panel_tabs: HBoxContainer
var active_panel := ""
var mobile_mode := true
var notice: Label
var notice_timer: Timer
var size_index := 0
var panel_tween: Tween
const SIZES := [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(800, 360)]

func _ready() -> void:
	state = State.new()
	state.request_build.connect(func(id: String) -> void: _show_notice("Preview: запрос на постройку «%s»" % State.BUILDINGS[id]["name"]))
	state.request_craft.connect(func(id: String) -> void: _show_notice("Preview: запрос на создание «%s»" % State.RECIPES[id]["name"]))
	state.request_select_item.connect(func(id: String) -> void: _show_notice("В руках: %s" % State.TOOLS[id]["name"]))
	state.request_close.connect(func() -> void: _show_notice("Панель закрыта"))
	resized.connect(_layout)
	queue_redraw()

	hud = HudScene.instantiate()
	hud.state = state
	hud.show_touch_controls = mobile_mode
	hud.open_inventory.connect(func() -> void: _open("inventory"))
	hud.open_building.connect(func() -> void: _open("build"))
	hud.open_crafting.connect(func() -> void: _open("craft"))
	hud.item_selected.connect(state.select_item)
	hud.action_requested.connect(func(action: String) -> void: _show_notice("Preview: %s" % action))
	add_child(hud)

	preview_tools = GridContainer.new()
	preview_tools.columns = 1
	preview_tools.add_theme_constant_override("h_separation", 5)
	preview_tools.add_theme_constant_override("v_separation", 5)
	add_child(preview_tools)
	var heading := Style.label("НАСТРОЙКИ PREVIEW", 11, Style.GOLD)
	preview_tools.add_child(heading)
	_add_tool("Ресурсы: мало", func() -> void: state.set_stock("scarce"))
	_add_tool("Ресурсы: много", func() -> void: state.set_stock("plenty"))
	_add_tool("Пустой рюкзак", func() -> void: state.set_stock("empty"))
	_add_tool("Touch: вкл/выкл", _toggle_mobile)
	_add_tool("Размер окна", _cycle_size)
	_add_tool("Сменить героя", _cycle_avatar)
	_add_tool("Загрузка: вкл/выкл", _toggle_loading)

	overlay = ColorRect.new()
	overlay.color = Color("080e12", 0.68)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	add_child(overlay)

	window_panel = PanelContainer.new()
	window_panel.add_theme_stylebox_override("panel", Style.panel())
	overlay.add_child(window_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	window_panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	panel_title = Style.label("ПУТЕВОЙ РЮКЗАК", 20, Style.GOLD)
	panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(panel_title)
	var close_button := Button.new()
	close_button.text = "✕"
	Style.button(close_button)
	close_button.pressed.connect(_close)
	header.add_child(close_button)
	panel_tabs = HBoxContainer.new()
	panel_tabs.add_theme_constant_override("separation", 5)
	column.add_child(panel_tabs)
	for pair in [["Рюкзак", "inventory"], ["Строить", "build"], ["Крафт", "craft"]]:
		var button := Button.new()
		button.name = pair[1]
		button.text = pair[0]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_open.bind(pair[1]))
		panel_tabs.add_child(button)
	content_scroll = ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(content_scroll)
	column.add_child(Style.label("PREVIEW · действия не изменяют игровой мир", 12, Style.MUTED))

	notice = Style.label("", 14, Style.TEXT)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.visible = false
	add_child(notice)
	notice_timer = Timer.new()
	notice_timer.one_shot = true
	notice_timer.wait_time = 2.5
	notice_timer.timeout.connect(func() -> void: notice.visible = false)
	add_child(notice_timer)
	_layout()

func _add_tool(caption: String, handler: Callable) -> void:
	var button := Button.new()
	button.text = caption
	Style.button(button)
	button.custom_minimum_size = Vector2(145, 44)
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(handler)
	preview_tools.add_child(button)

func _open(kind: String) -> void:
	if active_panel == kind:
		_close()
		return
	active_panel = kind
	overlay.visible = true
	hud.touch_layer.visible = false
	for child in content_scroll.get_children():
		child.queue_free()
	var panel: Control
	match kind:
		"inventory": panel = InventoryScene.instantiate()
		"build": panel = BuildingScene.instantiate()
		"craft": panel = CraftingScene.instantiate()
	panel.set("state", state)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.add_child(panel)
	if panel is EldoriaInventoryPanel:
		panel.item_selected.connect(state.select_item)
	elif panel is EldoriaBuildingPanel:
		panel.build_requested.connect(_request_build)
	elif panel is EldoriaCraftingPanel:
		panel.craft_requested.connect(_request_craft)
	panel_title.text = {"inventory": "ПУТЕВОЙ РЮКЗАК", "build": "СТРОИТЕЛЬСТВО", "craft": "МАСТЕРСКАЯ"}[kind]
	for tab in panel_tabs.get_children():
		Style.button(tab, tab.name == kind)
	_animate_panel(true)

func _close() -> void:
	if active_panel.is_empty():
		return
	active_panel = ""
	state.request_close.emit()
	_animate_panel(false)

func _animate_panel(opening: bool) -> void:
	if panel_tween != null and panel_tween.is_running():
		panel_tween.kill()
	panel_tween = create_tween()
	if opening:
		window_panel.modulate.a = 0.0
		window_panel.scale = Vector2(0.96, 0.96)
		panel_tween.tween_property(window_panel, "modulate:a", 1.0, 0.16)
		panel_tween.parallel().tween_property(window_panel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK)
	else:
		panel_tween.tween_property(window_panel, "modulate:a", 0.0, 0.12)
		panel_tween.parallel().tween_property(window_panel, "scale", Vector2(0.96, 0.96), 0.12)
		panel_tween.finished.connect(func() -> void:
			overlay.visible = false
			hud.touch_layer.visible = mobile_mode
		)

func _request_build(id: String) -> void:
	if state.can_afford(State.BUILDINGS[id]["cost"]):
		state.request_build.emit(id)

func _request_craft(id: String) -> void:
	if state.can_afford(State.RECIPES[id]["cost"]):
		state.request_craft.emit(id)

func _toggle_mobile() -> void:
	mobile_mode = not mobile_mode
	hud.show_touch_controls = mobile_mode
	hud.refresh()
	_show_notice("Touch: %s" % ("включён" if mobile_mode else "выключен"))

func _cycle_size() -> void:
	size_index = (size_index + 1) % SIZES.size()
	get_window().size = SIZES[size_index]
	_show_notice("Размер: %d × %d" % [SIZES[size_index].x, SIZES[size_index].y])

func _cycle_avatar() -> void:
	var avatars := ["knight", "rogue", "mage"]
	state.selected_avatar = avatars[(avatars.find(state.selected_avatar) + 1) % avatars.size()]
	state.changed.emit()

func _toggle_loading() -> void:
	state.loading = not state.loading
	state.changed.emit()
	_show_notice("Загрузка: %s" % ("включена" if state.loading else "выключена"))

func _show_notice(message: String) -> void:
	notice.text = message
	notice.visible = true
	notice_timer.start()
	_layout()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		_close()
	elif event.keycode >= KEY_1 and event.keycode <= KEY_6 and active_panel.is_empty():
		state.select_item(EldoriaHotbar.SLOTS[event.keycode - KEY_1])

func _layout() -> void:
	if preview_tools == null or window_panel == null:
		return
	preview_tools.position = Vector2(16, 166)
	if size.y < 490:
		preview_tools.columns = 4
	else:
		preview_tools.columns = 1
	preview_tools.size = preview_tools.get_combined_minimum_size()
	var width := minf(560, size.x - 24)
	var height := minf(520, size.y - 24)
	window_panel.position = Vector2((size.x - width) * 0.5, (size.y - height) * 0.5)
	window_panel.size = Vector2(width, height)
	window_panel.pivot_offset = window_panel.size * 0.5
	if notice != null:
		notice.position = Vector2(size.x * 0.5 - 230, 80)
		notice.size = Vector2(460, 36)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("344e64"))
	draw_rect(Rect2(0, size.y * 0.52, size.x, size.y * 0.48), Color("405d4e"))
	var ridge := PackedVector2Array([Vector2(0, size.y * 0.56), Vector2(size.x * 0.16, size.y * 0.26), Vector2(size.x * 0.33, size.y * 0.54), Vector2(size.x * 0.49, size.y * 0.22), Vector2(size.x * 0.7, size.y * 0.55), Vector2(size.x * 0.86, size.y * 0.3), Vector2(size.x, size.y * 0.51), Vector2(size.x, size.y), Vector2(0, size.y)])
	draw_colored_polygon(ridge, Color("263e47"))
	draw_rect(Rect2(0, size.y * 0.7, size.x, size.y * 0.3), Color("516b4d", 0.72))
