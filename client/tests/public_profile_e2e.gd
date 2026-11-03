extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var second := OS.get_cmdline_user_args().has("--restored")
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    if not second:
        game._choose_avatar(2) # select Mage before spawning; switching in world requires campfire
    game._join_websocket("wss://bacus.dev/eldoria/ws")
    for i in range(480):
        await process_frame
        if game.own_id != 0 and game.players.has(game.own_id) and game.player_inventories.has(game.own_id):
            break
    if game.own_id==0 or not game.players.has(game.own_id):
        _fail("failed WSS live login")
        return
    if not second:
        for i in range(140):
            await process_frame
            if game.player_choices.get(game.own_id,-1)==2:
                break
        if game.player_choices.get(game.own_id,-1)!=2:
            _fail("could not change avatar to Mage")
            return
        print("PUBLIC PROFILE INITIAL PASS avatar=Mage")
    else:
        if game.players[game.own_id].model_kind != "Mage":
            _fail("PostgreSQL did not restore Mage on reconnection")
            return
        print("PUBLIC PROFILE RESTORED PASS avatar=Mage")
    game._disconnect()
    quit(0)
func _fail(reason: String) -> void:
    printerr("PUBLIC PROFILE FAIL: "+reason)
    quit(1)
