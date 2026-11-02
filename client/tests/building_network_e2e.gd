extends SceneTree
const GAME := preload("res://Main.tscn")
var game: Node3D
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var a := OS.get_cmdline_user_args().has("--a")
    game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game._join_websocket("ws://127.0.0.1:7788")
    for i in range(480):
        await process_frame
        if game.own_id!=0 and game.players.size()>=2 and game.player_inventories.has(game.own_id):
            break
    if game.own_id == 0 or game.players.size()<2:
        _fail("not connected to both peers")
        return
    var world: Node3D = game.get_node("Eldoria_Forest")
    if a:
        for i in range(350):
            await process_frame
            if int(game.player_inventories.get(game.own_id,{}).get("wood",0))==8:
                break
        if int(game.player_inventories.get(game.own_id,{}).get("wood",0))!=8:
            _fail("missing resource grant")
            return
        game.build_selector.select(0)
        game._try_build()
        for i in range(55):
            await process_frame
        game.build_selector.select(1)
        game._try_build()
        for i in range(200):
            await process_frame
            if game.placed_buildings.size()==2:
                break
        if game.placed_buildings.size()!=2:
            _fail("builder did not receive two replicated buildings")
            return
        var inv: Dictionary=game.player_inventories.get(game.own_id,{})
        if inv.get("wood",-1)!=0 or inv.get("herb",-1)!=0:
            _fail("builder inventory not depleted")
            return
    else:
        for i in range(400):
            await process_frame
            if game.placed_buildings.size()==2:
                break
        if game.placed_buildings.size()!=2 or game.building_nodes.size()!=2:
            _fail("other player cannot see campfire/tent")
            return
        var inv: Dictionary=game.player_inventories.get(game.own_id,{})
        if int(inv.get("wood",-1))!=0:
            _fail("another player's inventory was modified")
            return
        game.request_build.rpc_id(1,"campfire",Vector3(200,0,200))
        for i in range(120):
            await process_frame
            if game.info.text.contains("Cannot build there"):
                break
        if not game.info.text.contains("Cannot build there") or game.placed_buildings.size()!=2:
            _fail("server rejection was silent or incorrectly created a building")
            return
    print("BUILD NETWORK CLIENT PASS "+("A" if a else "B")+" two synchronized 3D buildings")
    game._disconnect()
    quit(0)

func _fail(reason: String) -> void:
    printerr("BUILD NETWORK CLIENT FAIL: "+reason)
    quit(1)
