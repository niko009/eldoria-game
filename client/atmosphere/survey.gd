extends Node
## Offline, reproducible views of the actual Main scene. Never hosts or saves.
const VIEWS := [
    ["clearing_day", Vector3(-6, 5, 17), Vector3(0, 1, 0), false],
    ["forest_day", Vector3(24, 7, 24), Vector3(29, 3, 7), false],
    ["road", Vector3(1, 5, 36), Vector3(2, 1, 12), false],
    ["forest_night", Vector3(24, 7, 24), Vector3(29, 3, 7), true],
    ["camp_night", Vector3(-6, 5, 17), Vector3(0, 1, 2), true],
    ["landmark", Vector3(-25, 6, -10), Vector3(-25, 2, -24), false],
    ["encounter", Vector3(9, 4, 16), Vector3(2, 1, 5), true],
    ["stone_circle", Vector3(39, 6, 24), Vector3(33, 2, 13), true],
    ["old_camp", Vector3(-27, 8, 49), Vector3(-36, 4, 39), false],
    ["shore", Vector3(-15, 8, 36), Vector3(-29, 1, 22), false],
]
var game: Node3D
func _ready() -> void:
    get_window().mode = Window.MODE_WINDOWED
    get_window().grab_focus()
    DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
    game = preload("res://Main.tscn").instantiate()
    add_child(game)
    game.set_process(false)
    game.set_physics_process(false)
    game.player_ui.visible = false
    game._spawn(1, Vector3(0, 1.0, 4), 0)
    game._spawn(2, Vector3(-3, 1.0, 6), 1)
    game.wolf_actor.update_state(Vector3(3, 0.1, 7), 60, true)
    game._place_building(870, {"kind":"campfire", "x":1.0, "z":3.0})
    game._place_building(871, {"kind":"tent", "x":-4.0, "z":0.0})
    var high := not "--low" in OS.get_cmdline_user_args()
    var world := game.get_node("Eldoria_Forest")
    world.apply_detail_quality(high)
    game.GRAPHICS_SCRIPT.apply(game.GRAPHICS_SCRIPT.HIGH if high else game.GRAPHICS_SCRIPT.LOW, game.sunlight, game.foliage)
    game.ambience.set_high_detail(high)
    var destination := ""
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture-dir="):
            destination = arg.trim_prefix("--capture-dir=")
    if destination.is_empty():
        return # MCP interactive survey remains open.
    DirAccess.make_dir_recursive_absolute(destination)
    # Windows can suppress automatic rendering for an occluded window while
    # process_frame still fires. Explicitly render exactly one frame/sample on
    # both revisions, so throughput never measures a non-rendering idle loop.
    RenderingServer.render_loop_enabled = false
    var metrics: Array = []
    var views := VIEWS
    if "--sky-only" in OS.get_cmdline_user_args():
        views = [["night_sky",Vector3(0,3,14),Vector3(-35,51,-66),true]]
    for view in views:
        print("SURVEY VIEW ", view[0])
        game.camera.position = view[1]
        game.camera.look_at(view[2])
        game._apply_raid_lighting("night" if view[3] else "prepare")
        game.ambience.update_campfires(game.building_nodes, view[2])
        await get_tree().create_timer(1.5).timeout
        var samples: Array[float] = []
        var draws := 0.0
        for i in 90:
            var begin := Time.get_ticks_usec()
            RenderingServer.force_draw()
            await get_tree().process_frame
            samples.append((Time.get_ticks_usec() - begin) / 1000.0)
            draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
        var total := 0.0
        for ms in samples:
            total += ms
        samples.sort()
        RenderingServer.force_draw()
        var error := get_viewport().get_texture().get_image().save_png(destination + "/" + view[0] + ".png")
        assert(error == OK, "Screenshot save failed")
        metrics.append({"view":view[0], "fps":90000.0 / total, "p95_ms":samples[85],
            "draw_calls":draws / 90.0, "static_memory_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0})
    var file := FileAccess.open(destination + "/metrics.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(metrics, "  "))
    print("TASK087 SURVEY PASS ", destination)
    get_tree().quit()
