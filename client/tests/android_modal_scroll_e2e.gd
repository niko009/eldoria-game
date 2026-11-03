extends SceneTree
# TASK-030: finger drag over actual menu Buttons on Android landscape.
# Uses Input.parse_input_event, not a direct call to the scroll helper.
const GAME := preload("res://Main.tscn")
const PREVIEW := preload("res://ui_preview/UiPreview.tscn")
const SMALL := Vector2i(800, 360)
var failures := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    root.size = SMALL
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var ui = game.live_ui
    if ui == null:
        _fail("live UI unavailable")
        return
    ui.size = Vector2(SMALL)
    ui._layout()
    var actions: Array[String] = []
    ui.action_requested.connect(func(id: String) -> void: actions.append(id))
    for kind in ["settings", "inventory", "build", "craft"]:
        if kind == "inventory":
            ui.set_inventory({"wood": 6, "stone": 6, "herb": 6, "axe": 1})
            ui.state.select_item("axe")
        ui._open(kind)
        for i in range(3):
            await process_frame
        var scroller: ScrollContainer = ui.contents
        var height: float = scroller.get_child(0).get_combined_minimum_size().y
        print("MODAL ", kind, " area=",scroller.size.y, " content=",height)
        if scroller.scroll_vertical != 0:
            _fail(kind + " did not start at top")
            return
        var point: Vector2 = scroller.get_global_rect().position + Vector2(scroller.size.x * 0.42, 90)
        if kind == "settings":
            # A swipe on settings buttons must never execute their actions.
            await _drag(point, 170, 0)
            if ui.active_panel != kind or not actions.is_empty():
                _fail("scroll accidentally activated a settings Button: active=" + ui.active_panel + " actions=" + str(actions))
                return
        else:
            await _drag(point, 170, 0)
        if kind == "inventory" and ui.state.selected_item != "axe":
            _fail("inventory swipe selected a resource instead of scrolling")
            return
        if height > scroller.size.y + 15:
            var min_expected := mini(25, floori(height - scroller.size.y))
            if scroller.scroll_vertical < min_expected - 2:
                _fail(kind + " did not scroll on finger swipe")
                return
            var previous: int = scroller.scroll_vertical
            await _drag(point, -120, 0)
            if scroller.scroll_vertical >= previous:
                _fail(kind + " failed to scroll back")
                return
        elif scroller.scroll_vertical != 0:
            _fail(kind + " scrolled despite fitting in viewport")
            return
    ui._close()
    await process_frame
    var closed_scroll: int = ui.contents.scroll_vertical
    await _drag(Vector2(400, 200), 110, 0)
    if ui.contents.scroll_vertical != closed_scroll:
        _fail("closed modal was scrollable")
        return
    ui._open("settings")
    for i in range(4):
        await process_frame
    # A genuine short touch/tap must still activate the settings button.
    var quality: Button = ui.current_panel.get_child(1)
    await _tap(quality.get_global_rect().get_center(), 0)
    if actions != ["quality"] or not ui.active_panel.is_empty():
        _fail("ordinary tap was suppressed after swipe: " + str(actions))
        return
    game.queue_free()
    await process_frame
    # Same reusable touch scroll fix must work inside the standalone UI preview.
    var preview: Control = PREVIEW.instantiate()
    root.add_child(preview)
    await process_frame
    preview._layout()
    preview._open("inventory")
    for i in range(3):
        await process_frame
    var scroll: ScrollContainer = preview.content_scroll
    if scroll.get_child(0).get_combined_minimum_size().y > scroll.size.y + 15:
        var p: Vector2 = scroll.get_global_rect().position + Vector2(scroll.size.x * 0.5, 70)
        await _drag(p, 155, 0)
        if scroll.scroll_vertical < 25:
            _fail("UI preview inventory cannot scroll")
            return
    print("ANDROID_MODAL_SCROLL_E2E PASS live settings/inventory/build/craft and preview")
    preview.queue_free()
    quit(0)

func _tap(at: Vector2, finger: int) -> void:
    var p := _event_position(at)
    var down := InputEventScreenTouch.new()
    down.index = finger
    down.position = p
    down.pressed = true
    Input.parse_input_event(down)
    await process_frame
    var up := InputEventScreenTouch.new()
    up.index = finger
    up.position = p
    up.pressed = false
    Input.parse_input_event(up)
    await process_frame

func _event_position(point: Vector2) -> Vector2:
    var canvas := Vector2(
        float(ProjectSettings.get_setting("display/window/size/viewport_width")),
        float(ProjectSettings.get_setting("display/window/size/viewport_height")))
    return point * (Vector2(root.size) / canvas)

func _drag(start: Vector2, dy: float, finger: int) -> void:
    # The test window is 800x360 but the Godot project canvas is 1280x720.
    # Convert to the physical event coordinates accepted by parse_input_event.
    var factor := _event_position(Vector2.ONE)
    var down := InputEventScreenTouch.new()
    down.index = finger
    down.position = start * factor
    down.pressed = true
    Input.parse_input_event(down)
    await process_frame
    for i in range(12):
        var drag := InputEventScreenDrag.new()
        drag.index = finger
        drag.relative = Vector2(0, -dy / 12.0) * factor
        drag.position = (start + Vector2(0, -dy * (i + 1) / 12.0)) * factor
        Input.parse_input_event(drag)
        await process_frame
    var up := InputEventScreenTouch.new()
    up.index = finger
    up.position = (start + Vector2(0, -dy)) * factor
    up.pressed = false
    Input.parse_input_event(up)
    await process_frame

func _fail(why: String) -> void:
    printerr("ANDROID_MODAL_SCROLL_E2E FAIL: " + why)
    quit(1)
