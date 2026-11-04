extends RefCounted
## Touch scrolling that works when a child Button consumes GUI gestures.
## Only intercepts a single finger inside the visible ScrollContainer viewport.
## Desktop wheel/trackpad scrolling stays owned by Godot ScrollContainer.
class_name EldoriaTouchScroller

const DRAG_DEADZONE := 8.0
var finger := -1
var start_scroll := 0
var cumulative_y := 0.0
var scrolling := false
var muted_buttons: Array[BaseButton] = []
var restore_generation := 0

func reset() -> void:
    restore_generation += 1
    _restore_buttons()
    finger = -1
    start_scroll = 0
    cumulative_y = 0.0
    scrolling = false

func handle(event: InputEvent, scroll: ScrollContainer, is_open: bool, viewport: Viewport) -> void:
    if not is_open or scroll == null or not scroll.is_visible_in_tree():
        reset()
        return
    if event is InputEventScreenTouch:
        var touch := event as InputEventScreenTouch
        if touch.pressed:
            if finger == -1 and scroll.get_global_rect().has_point(touch.position):
                restore_generation += 1
                _restore_buttons()
                finger = touch.index
                start_scroll = scroll.scroll_vertical
                cumulative_y = 0.0
                scrolling = false
        elif touch.index == finger:
            if scrolling:
                viewport.set_input_as_handled()
                # Godot can also synthesize a mouse release from this touch.
                # Defer unblocking Button signals until after that event.
                restore_generation += 1
                var generation := restore_generation
                viewport.get_tree().create_timer(0.04).timeout.connect(func() -> void:
                    if generation == restore_generation:
                        _restore_buttons())
            else:
                _restore_buttons()
            finger = -1
            cumulative_y = 0.0
            scrolling = false
    elif event is InputEventScreenDrag:
        var drag := event as InputEventScreenDrag
        if drag.index != finger:
            return
        cumulative_y += drag.relative.y
        if absf(cumulative_y) >= DRAG_DEADZONE:
            if not scrolling:
                _mute_buttons(scroll)
            scrolling = true
        if scrolling:
            # The ScrollContainer may have interactive Buttons as children;
            # _input receives ScreenDrag even when their mouse_filter is STOP.
            scroll.scroll_vertical = start_scroll - roundi(cumulative_y)
            viewport.set_input_as_handled()

func _mute_buttons(root: Node) -> void:
    var stack: Array[Node] = [root]
    while not stack.is_empty():
        var node: Node = stack.pop_back()
        if node is BaseButton:
            var button := node as BaseButton
            if not button.is_blocking_signals():
                button.set_block_signals(true)
                muted_buttons.append(button)
        for child in node.get_children():
            stack.append(child)

func _restore_buttons() -> void:
    for button in muted_buttons:
        if is_instance_valid(button):
            button.set_block_signals(false)
    muted_buttons.clear()
