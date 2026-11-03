extends Control
## TASK-021B: live-client bridge. UI is deliberately not instantiated by dedicated servers.
## Server remains the source of truth for inventory and building results.

signal action_requested(action: String)
signal build_requested(kind: String)
signal craft_requested(recipe_id: String)
signal equip_requested(equip: bool)
signal preview_requested(kind: String)
signal joystick_moved(direction: Vector2)

const State = preload("res://ui/mock_game_ui_state.gd")
const Style = preload("res://ui/ui_style.gd")
const HudScene = preload("res://ui/GameHud.tscn")
const InventoryScene = preload("res://ui/InventoryPanel.tscn")
const BuildingScene = preload("res://ui/BuildingPanel.tscn")
const CraftingScene = preload("res://ui/CraftingPanel.tscn")
const TouchScroller = preload("res://ui/touch_scroll.gd")

var state: MockGameUiState
var hud: EldoriaGameHud
var overlay: ColorRect
var dialog: PanelContainer
var panel_title: Label
var tabs: HBoxContainer
var contents: ScrollContainer
var active_panel := ""
var current_panel: Control
var notice: Label
var notice_timer: Timer
var panel_tween: Tween
var touch_scroll = TouchScroller.new()
var combat_equipment := "unarmed"
var bow_aim_hint: Label

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    state = State.new()
    state.set_stock("empty")
    state.health_known = false
    state.near_campfire = false
    state.connection_status = "Подключение..."
    state.selected_avatar = "knight"
    state.request_select_item.connect(_selected_item)
    state.changed.connect(_refresh_bow_hint)
    resized.connect(_layout)

    hud = HudScene.instantiate()
    hud.state = state
    hud.preview_mode = false
    hud.show_touch_controls = OS.get_name() == "Android" or OS.get_cmdline_user_args().has("--test-mobile-ui") or OS.get_cmdline_user_args().has("--test-live-ui")
    hud.open_inventory.connect(func() -> void: _open("inventory"))
    hud.open_building.connect(func() -> void: _open("build"))
    hud.open_crafting.connect(func() -> void: _open("craft"))
    hud.open_settings.connect(func() -> void: _open("settings"))
    hud.item_selected.connect(state.select_item)
    hud.action_requested.connect(_on_action)
    add_child(hud)
    bow_aim_hint = Style.label("+", 29, Color("f1e3ba"))
    bow_aim_hint.name = "BowAimReticle"
    bow_aim_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bow_aim_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    bow_aim_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    bow_aim_hint.visible = false
    add_child(bow_aim_hint)
    hud.joystick.direction_changed.connect(func(vector: Vector2) -> void: joystick_moved.emit(vector))

    overlay = ColorRect.new()
    overlay.color = Color("071113", 0.64)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.visible = false
    add_child(overlay)
    dialog = PanelContainer.new()
    dialog.add_theme_stylebox_override("panel", Style.panel(Color("142329", 0.97), Color("d4b781", 0.61), 20))
    overlay.add_child(dialog)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 7)
    dialog.add_child(col)
    var header := HBoxContainer.new()
    col.add_child(header)
    panel_title = Style.label("", 21, Style.GOLD)
    panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(panel_title)
    var close_button := Button.new()
    close_button.text = "✕"
    close_button.tooltip_text = "Закрыть"
    Style.button(close_button)
    close_button.pressed.connect(_close)
    header.add_child(close_button)
    tabs = HBoxContainer.new()
    tabs.add_theme_constant_override("separation", 5)
    col.add_child(tabs)
    for entry in [["Рюкзак", "inventory"], ["Строить", "build"], ["Крафт", "craft"], ["Настройки", "settings"]]:
        var btn := Button.new()
        btn.text = entry[0]
        btn.name = entry[1]
        btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        btn.pressed.connect(_open.bind(entry[1]))
        tabs.add_child(btn)
    var accent := ColorRect.new()
    accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
    accent.custom_minimum_size = Vector2(0, 2)
    accent.color = Color("d4b781", 0.45)
    col.add_child(accent)
    contents = ScrollContainer.new()
    contents.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    contents.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
    contents.scroll_deadzone = 8
    contents.size_flags_vertical = Control.SIZE_EXPAND_FILL
    col.add_child(contents)
    notice = Style.label("", 14)
    notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    notice.visible = false
    notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(notice)
    notice_timer = Timer.new()
    notice_timer.one_shot = true
    notice_timer.wait_time = 3.0
    notice_timer.timeout.connect(func() -> void: notice.visible = false)
    add_child(notice_timer)
    _layout()

func set_combat_equipment(item: String) -> void:
    combat_equipment = item
    _refresh_bow_hint()

func _refresh_bow_hint() -> void:
    if bow_aim_hint == null or state == null:
        return
    bow_aim_hint.visible = combat_equipment == "bow" and active_panel.is_empty()
    bow_aim_hint.tooltip_text = "Лук · стрел: %d · цельтесь поворотом камеры" % state.amount("arrow")

func set_inventory(inventory: Dictionary) -> void:
    var validated := {}
    for item_id in State.ITEMS:
        var limit := 1 if ["axe", "spear", "bow", "shield"].has(item_id) else 40 if item_id == "arrow" else 20 if ["bandage", "repair_kit"].has(item_id) else 1000000
        validated[item_id] = clampi(int(inventory.get(item_id, 0)), 0, limit)
    if state.inventory == validated:
        return
    state.inventory = validated
    if int(validated.get("axe", 0)) == 0:
        state.equipped_axe = false
        if state.selected_item == "axe":
            state.select_item("unarmed")
    state.changed.emit()

func set_health(hp: int, maximum: int) -> void:
    var value := clampi(hp, 0, 100)
    if state.health != value or not state.health_known:
        state.health_known = true
        state.health = value
        state.max_health = maxi(1, maximum)
        state.changed.emit()

func reset_health() -> void:
    if state != null:
        state.health_known = false
        state.changed.emit()

func set_equipped_axe(equipped: bool) -> void:
    if state == null:
        return
    var value := equipped and state.amount("axe") > 0
    if state.equipped_axe != value:
        state.equipped_axe = value
        state.changed.emit()

func _selected_item(item_id: String) -> void:
    # UI state is visual only: the actual equipment is acknowledged by server.
    equip_requested.emit(item_id == "axe")

func set_near_campfire(near: bool) -> void:
    if state != null and state.near_campfire != near:
        state.near_campfire = near
        state.changed.emit()

func set_raid_status(phase: String, round_number: int, kills: int, goal: int, seconds: int) -> void:
    if hud != null:
        hud.set_raid_status(phase, round_number, kills, goal, seconds)

func set_camp_health(hp: int, maximum: int) -> void:
    if hud != null:
        hud.set_camp_health(hp, maximum)

func set_practice_points(points: int) -> void:
    if hud != null:
        hud.set_practice_points(points)

func set_skills(skills: Dictionary) -> void:
    if hud != null:
        hud.set_skills(skills)

func set_status(message: String) -> void:
    if state != null and state.connection_status != message:
        state.connection_status = message
        state.changed.emit()

func set_avatar(choice: int) -> void:
    if state == null:
        return
    var avatars := ["knight", "rogue", "mage"]
    if choice >= 0 and choice < avatars.size():
        state.selected_avatar = avatars[choice]
        state.changed.emit()

func show_message(message: String) -> void:
    if notice == null:
        return
    notice.text = message
    notice.visible = true
    notice_timer.start()
    _layout()

func _open(kind: String) -> void:
    if kind == active_panel:
        _close()
        return
    active_panel = kind
    _refresh_bow_hint()
    touch_scroll.reset()
    # Opening an overlay must never leave a touch movement vector latched.
    hud.joystick.dragging = false
    hud.joystick._set_direction(hud.joystick.size * 0.5)
    joystick_moved.emit(Vector2.ZERO)
    overlay.visible = true
    hud.touch_layer.visible = false
    for child in contents.get_children():
        contents.remove_child(child)
        child.queue_free()
    contents.scroll_vertical = 0
    if kind == "settings":
        current_panel = _settings_panel()
        contents.add_child(current_panel)
    else:
        match kind:
            "inventory": current_panel = InventoryScene.instantiate()
            "build": current_panel = BuildingScene.instantiate()
            "craft": current_panel = CraftingScene.instantiate()
        current_panel.set("state", state)
        contents.add_child(current_panel)
        if current_panel is EldoriaInventoryPanel:
            current_panel.item_selected.connect(state.select_item)
        elif current_panel is EldoriaBuildingPanel:
            current_panel.preview_available = true
            current_panel.preview_requested.connect(_preview_build)
            current_panel.build_requested.connect(_build)
        elif current_panel is EldoriaCraftingPanel:
            current_panel.craft_enabled = true
            current_panel.craft_requested.connect(_craft)
            current_panel.use_requested.connect(func(recipe_id: String) -> void:
                _close()
                action_requested.emit(recipe_id))
    current_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    panel_title.text = {"inventory": "РЮКЗАК", "build": "СТРОИТЕЛЬСТВО", "craft": "МАСТЕРСКАЯ", "settings": "НАСТРОЙКИ"}[kind]
    for tab in tabs.get_children():
        Style.button(tab, tab.name == kind)
    _animate(true)

func _settings_panel() -> VBoxContainer:
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 8)
    for entry in [["Переподключиться", "reconnect"], ["Графика: переключить", "quality"], ["Диагностика FPS (F9)", "performance_debug"], ["Звук: вкл/выкл", "sound"], ["Телеметрия: вкл/выкл", "telemetry"], ["Сменить героя", "avatar"], ["Предпросмотр постройки (V)", "preview"], ["Отключиться", "disconnect"]]:
        var btn := Button.new()
        btn.text = entry[0]
        Style.button(btn)
        btn.pressed.connect(_settings_action.bind(entry[1]))
        col.add_child(btn)
    return col

func _settings_action(kind: String) -> void:
    action_requested.emit(kind)
    _close()

func _build(kind: String) -> void:
    if not State.BUILDINGS.has(kind) or not state.can_afford(State.BUILDINGS[kind]["cost"]):
        show_message("Недостаточно ресурсов")
        return
    _close()
    build_requested.emit(kind)

func _preview_build(kind: String) -> void:
    if not State.BUILDINGS.has(kind):
        return
    _close()
    preview_requested.emit(kind)

func _craft(recipe_id: String) -> void:
    if not state.near_campfire or not state.recipe_materials_ready(recipe_id):
        return
    if state.loading:
        return
    _close()
    craft_requested.emit(recipe_id)

func _on_action(kind: String) -> void:
    if kind == "inventory":
        _open("inventory")
    else:
        action_requested.emit(kind)

func _close() -> void:
    if active_panel.is_empty():
        return
    active_panel = ""
    _refresh_bow_hint()
    touch_scroll.reset()
    state.request_close.emit()
    _animate(false)

func _animate(opening: bool) -> void:
    if panel_tween != null and panel_tween.is_running():
        panel_tween.kill()
    panel_tween = create_tween()
    if opening:
        dialog.modulate.a = 0.0
        panel_tween.tween_property(dialog, "modulate:a", 1.0, 0.14)
    else:
        panel_tween.tween_property(dialog, "modulate:a", 0.0, 0.11)
        panel_tween.finished.connect(func() -> void:
            overlay.visible = false
            hud.touch_layer.visible = hud.show_touch_controls
            )

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE:
            if active_panel.is_empty():
                _open("settings")
            else:
                _close()
            get_viewport().set_input_as_handled()
        elif event.keycode >= KEY_1 and event.keycode <= KEY_6 and active_panel.is_empty():
            state.select_item(EldoriaHotbar.SLOTS[event.keycode - KEY_1])

func _input(event: InputEvent) -> void:
    # Always receive ScreenDrag even when a settings/inventory Button has
    # mouse_filter=STOP; the scroll helper only handles an open modal.
    touch_scroll.handle(event, contents, not active_panel.is_empty(), get_viewport())

func _layout() -> void:
    if dialog == null:
        return
    if bow_aim_hint != null:
        bow_aim_hint.size = Vector2(44, 44)
        bow_aim_hint.position = size*0.5 - bow_aim_hint.size*0.5
    var mobile := OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--test-live-ui") or OS.get_cmdline_user_args().has("--test-mobile-ui")
    var top_margin := 49.0 if mobile else 16.0
    var bottom_margin := 30.0 if mobile else 16.0
    var width := minf(560, size.x - 32)
    var height := minf(460, size.y - top_margin - bottom_margin)
    dialog.position = Vector2((size.x - width) * 0.5, maxf(top_margin, (size.y - height) * 0.5))
    dialog.size = Vector2(width, height)
    if notice != null:
        notice.position = Vector2(maxf(10, size.x * 0.5 - 230), 90)
        notice.size = Vector2(minf(460, size.x - 20), 40)
