extends SceneTree
const GAME := preload("res://Main.tscn")
const BUILD := preload("res://building_object.gd")
var game: Node3D

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game._host()
    var player_id: int = game.own_id
    var world: Node3D = game.get_node("Eldoria_Forest")
    var camp := Vector3(0,world.height_at(0,-4),-4)
    var tent := Vector3(-4,world.height_at(-4,0),0)
    game.player_inventories[player_id] = {"wood":8,"stone":2,"herb":2}
    if not game._is_valid_build_spot("campfire",camp,game.players[player_id].position):
        _fail("camp placement invalid on starting clearing")
        return
    if not game._build_on_server(player_id,"campfire",camp):
        _fail("could not construct campfire")
        return
    var saved: Dictionary = game.player_inventories[player_id]
    if int(saved["wood"]) != 5 or int(saved["stone"]) != 0:
        _fail("campfire did not debit wood and stone correctly")
        return
    if game._build_on_server(player_id,"campfire",camp) or game.placed_buildings.size()!=1:
        _fail("duplicate overlapping campfire accepted")
        return
    if not game._is_valid_build_spot("tent",tent,game.players[player_id].position):
        _fail("tent placement invalid")
        return
    if not game._build_on_server(player_id,"tent",tent):
        _fail("could not construct tent")
        return
    saved = game.player_inventories[player_id]
    if saved != game._empty_inventory():
        _fail("tent cost wrong: "+str(saved))
        return
    var count: int = game.placed_buildings.size()
    if count != 2 or game._build_on_server(player_id,"tent",Vector3(100,0,100)):
        _fail("out-of-range building accepted")
        return
    if game._build_on_server(player_id,"tent",Vector3(INF,0,0)):
        _fail("infinite building position accepted")
        return
    if game._build_on_server(player_id,"evil",tent):
        _fail("unknown building kind accepted")
        return
    if game.placed_buildings.size()!=count:
        _fail("rejected placement modified the world")
        return
    for id in game.placed_buildings.keys():
        var b = game.placed_buildings[id]
        if not BUILD.is_valid_kind(b["kind"]):
            _fail("invalid building stored")
            return
    print("BUILD LOGIC PASS: campfire + tent, resource costs, overlap, invalid kind, bounds, finite coordinates")
    game._disconnect()
    quit(0)

func _fail(message: String) -> void:
    printerr("BUILD LOGIC FAIL: "+message)
    quit(1)
