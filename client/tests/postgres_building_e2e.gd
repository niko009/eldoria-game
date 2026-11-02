extends SceneTree
const GAME := preload("res://Main.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var restored := OS.get_cmdline_user_args().has("--restored")
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game._host()
    if game.own_id == 0:
        _fail("host unavailable")
        return
    var world: Node3D = game.get_node("Eldoria_Forest")
    var camp := Vector3(0,world.height_at(0,-4),-4)
    var tent := Vector3(-4,world.height_at(-4,0),0)
    if not restored:
        game.player_inventories[game.own_id]={"wood":8,"stone":2,"herb":2}
        if not game._build_on_server(game.own_id,"campfire",camp):
            _fail("DB backed campfire build failed")
            return
        if not game._build_on_server(game.own_id,"tent",tent):
            _fail("DB backed tent build failed")
            return
        if game.placed_buildings.size()!=2:
            _fail("build list after saving isn't two")
            return
        print("POSTGRES BUILD INITIAL PASS two saved buildings")
    else:
        if game.placed_buildings.size()!=2:
            _fail("world did not restore both buildings")
            return
        if game.building_nodes.size()!=2:
            _fail("world did not instantiate two persisted 3D buildings")
            return
        var kinds := []
        for entry in game.placed_buildings.values():
            kinds.append(str(entry["kind"]))
        if not "tent" in kinds or not "campfire" in kinds:
            _fail("restored wrong models: "+str(kinds))
            return
        var invalid: bool = game._build_on_server(game.own_id,"tent",tent)
        if invalid or game.placed_buildings.size()!=2:
            _fail("overlap after restart bypassed")
            return
        print("POSTGRES BUILD RESTORED PASS campfire + tent after real server restart")
    game._disconnect()
    quit(0)

func _fail(message: String) -> void:
    printerr("POSTGRES BUILD FAIL: "+message)
    quit(1)
