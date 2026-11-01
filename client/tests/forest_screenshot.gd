extends SceneTree
const SCENE := preload("res://Main.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var game := SCENE.instantiate()
    root.add_child(game)
    game.player_ui.visible = false # screenshot only, UI remains in actual game
    game.camera.position = Vector3(-4, 7.7, 22)
    game.camera.look_at(Vector3(-2, 2.0, -18), Vector3.UP)
    await process_frame
    for i in range(70):
        await process_frame
    var image := root.get_texture().get_image()
    var dest := ProjectSettings.globalize_path("res://../builds/eldoria-forest-preview.png")
    var err := image.save_png(dest)
    if err != OK:
        printerr("SCREENSHOT FAILED %d" % err)
        quit(1)
        return
    print("FOREST SCREENSHOT SAVED %s %sx%s" % [dest,image.get_width(),image.get_height()])
    quit(0)
