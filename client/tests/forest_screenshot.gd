extends SceneTree
const SCENE := preload("res://Main.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var game := SCENE.instantiate()
    root.add_child(game)
    game.player_ui.visible = false # screenshot only, UI remains in actual game
    game._spawn(3, Vector3(-1.0, 1.0, 6.0)) # Knight
    game._spawn(2, Vector3(4.0, 1.0, 0.0))  # Mage
    game._spawn(1, Vector3(-6.0, 1.0, -4.0)) # Rogue
    game.camera.position = Vector3(-1.5, 5.0, 16.0)
    game.camera.look_at(Vector3(-1.0, 1.5, -2.0), Vector3.UP)
    await process_frame
    for i in range(7):
        await process_frame
    var image := root.get_texture().get_image()
    var dest := ProjectSettings.globalize_path("res://../builds/eldoria-character-preview.png")
    var err := image.save_png(dest)
    if err != OK:
        printerr("SCREENSHOT FAILED %d" % err)
        quit(1)
        return
    print("FOREST SCREENSHOT SAVED %s %sx%s" % [dest,image.get_width(),image.get_height()])
    quit(0)
