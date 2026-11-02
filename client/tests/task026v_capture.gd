extends SceneTree

const SCENE := preload("res://Main.tscn")
const GRAPHICS := preload("res://graphics_profile.gd")
const BUILDING := preload("res://building_object.gd")
const VIEWS := {
    "camp": [Vector3(-1.5, 5.0, 16.0), Vector3(-1.0, 1.5, -2.0)],
    "forest": [Vector3(18.0, 7.0, -28.0), Vector3(5.0, 2.0, -38.0)],
    "lake": [Vector3(-16.0, 8.0, 35.0), Vector3(-29.0, 1.0, 22.0)]
}

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var args := OS.get_cmdline_user_args()
    var stage := "after" if args.has("--after") else "before"
    var hud := args.has("--hud")
    var campfire := args.has("--campfire")
    var game := SCENE.instantiate()
    root.add_child(game)
    if not hud:
        game.player_ui.visible = false
    game._spawn(3, Vector3(-1.0, 1.0, 6.0))
    var forest: Node3D = game.get_node("Eldoria_Forest")
    if campfire:
        var fire: Node3D = BUILDING.new()
        fire.setup(1, "campfire", Vector3(2.0, forest.height_at(2.0, -1.0), -1.0))
        game.add_child(fire)
    var signature := 0
    for item in forest.resources:
        signature = (signature * 31 + int(item["id"]) * 17 + int(item["pos"].x * 100.0) + int(item["pos"].z * 100.0)) % 2147483647
    print("RESOURCE_SIGNATURE count=%d hash=%d" % [forest.resources.size(), signature])
    if forest.resources.size() != 347 or signature != 1181774555:
        printerr("RESOURCE_SIGNATURE CHANGED")
        quit(1)
        return
    var folder := "task026v_concept" if args.has("--concept") else "task026v"
    var output := ProjectSettings.globalize_path("res://../docs/screenshots/" + folder)
    DirAccess.make_dir_recursive_absolute(output)
    for view in VIEWS.keys():
        if campfire and view != "camp":
            continue
        for quality in [GRAPHICS.LOW, GRAPHICS.HIGH]:
            if campfire and quality != GRAPHICS.HIGH:
                continue
            game.graphics_quality = quality
            GRAPHICS.apply(quality, game.sunlight, game.foliage)
            forest.apply_detail_quality(quality == GRAPHICS.HIGH)
            game.camera.position = VIEWS[view][0]
            game.camera.look_at(VIEWS[view][1], Vector3.UP)
            for i in range(12):
                await process_frame
            var image := root.get_texture().get_image()
            var file := "%s/%s_%s_%s%s%s.png" % [output, stage, view, "low" if quality == GRAPHICS.LOW else "high", "_hud" if hud else "", "_fire" if campfire else ""]
            var error := image.save_png(file)
            if error != OK:
                printerr("CAPTURE FAILED %d %s" % [error, file])
                quit(1)
                return
            print("CAPTURE %s %dx%d" % [file, image.get_width(), image.get_height()])
    quit(0)
