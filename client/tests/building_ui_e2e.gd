extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game._host()
    game._try_build()
    if game.placed_buildings.size()!=0 or not game.info.text.contains("Need resources"):
        _fail("invisible failure when inventory is empty: "+game.info.text)
        return
    game.player_inventories[game.own_id] = {"wood":8,"stone":2,"herb":2}
    game.build_selector.select(0)
    game._try_build()
    if game.placed_buildings.size()!=1 or not game.info.text.contains("built successfully"):
        _fail("automatic campfire placement did not work: "+game.info.text)
        return
    game.build_selector.select(1)
    game._try_build()
    if game.placed_buildings.size()!=2 or not game.info.text.contains("built successfully"):
        _fail("automatic tent placement did not work: "+game.info.text)
        return
    if game.player_inventories[game.own_id] != {"wood":0,"stone":0,"herb":0,"axe":0}:
        _fail("invalid inventory after building")
        return
    game._try_build()
    if game.placed_buildings.size()!=2 or not game.info.text.contains("Need resources"):
        _fail("missing clear feedback for insufficient inventory")
        return
    print("BUILD UI PASS: actual Build handler finds clear spots, builds two types, shows success and failure")
    game._disconnect()
    quit(0)
func _fail(reason: String) -> void:
    printerr("BUILD UI FAIL: "+reason)
    quit(1)
