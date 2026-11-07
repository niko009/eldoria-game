extends SceneTree
# Non-production HUD capture and geometry baseline. Screenshots are local QA artifacts.
const MAIN := preload("res://Main.tscn")
const SIZES := [Vector2i(1280, 720), Vector2i(1280, 576), Vector2i(800, 360)]

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game: Node3D = MAIN.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    if game.live_ui == null:
        _fail("live UI missing")
        return
    var ui: Control = game.live_ui
    ui.set_inventory({"wood": 14, "stone": 8, "herb": 7, "bow": 1, "arrow": 5, "bandage": 2})
    ui.set_health(73, 100)
    ui.set_status("Connected, ID 123")
    for display in SIZES:
        root.size = display
        for frame in range(6):
            await process_frame
        for hero in [0, 2]:
            ui.hud.set_hero_class(hero)
            ui.hud._layout()
            await process_frame
            # Stretch mode maps 800x360 to a larger logical UI viewport.
            # Compare global Control coordinates to the logical HUD bounds.
            var screen: Rect2 = ui.hud.get_global_rect()
            var controls: Dictionary = {"status":ui.hud.status_panel, "resources":ui.hud.resources_panel,
                "hotbar":ui.hud.hotbar, "joystick":ui.hud.joystick, "menu":ui.hud.top_actions}
            for key in ui.hud.action_controls:
                if ui.hud.action_controls[key].visible:
                    controls["action_" + key] = ui.hud.action_controls[key]
            for key in controls:
                var bounds: Rect2 = controls[key].get_global_rect()
                if not screen.encloses(bounds):
                    _fail("offscreen %s %s at %s" % [key, bounds, display])
                    return
            for frame in range(4):
                await process_frame
            var filename := "user://task087-hud-%dx%d-class%d.png" % [display.x, display.y, hero]
            var error := root.get_texture().get_image().save_png(filename)
            if error != OK:
                _fail("capture %s error %d" % [filename, error])
                return
            print("TASK087 HUD CAPTURE PASS ", filename, " viewport=", display, " class=", hero)
    game.queue_free()
    quit(0)

func _fail(message: String) -> void:
    printerr("TASK087 HUD AUDIT FAIL: " + message)
    quit(1)
