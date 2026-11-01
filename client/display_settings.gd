extends RefCounted

# The only window-mode implementation. Android uses OS-managed orientation/size.
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

static func set_windowed_resolution(size: Vector2i) -> void:
    if DisplayServer.get_name() == "headless":
        return
    DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
    DisplayServer.window_set_size(size)

static func toggle_fullscreen() -> void:
    if DisplayServer.get_name() == "headless":
        return
    if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
    else:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
