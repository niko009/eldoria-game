extends SceneTree
const GAME := preload("res://Main.tscn")
var game: Node3D
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    game = GAME.instantiate()
    root.add_child(game)
    for i in range(450):
        await process_frame
        if game.players.size() >= 2:
            break
    if game.players.size() != 2:
        _fail("two clients did not join")
        return
    var keys: Array = game.players.keys()
    var first_id: int = keys[0]
    game.player_inventories[first_id] = {"wood":8,"stone":2,"herb":2}
    game.inventory_snapshot.rpc_id(first_id,game.player_inventories[first_id])
    print("BUILD NETWORK SERVER GRANTED INVENTORY TO %d" % first_id)
    for i in range(550):
        await process_frame
        if game.placed_buildings.size()==2:
            print("BUILD NETWORK SERVER PASS two buildings created")
            quit(0)
            return
    _fail("expected two server buildings")

func _fail(message: String) -> void:
    printerr("BUILD NETWORK SERVER FAIL: "+message)
    quit(1)
