extends SceneTree
const GAME := preload("res://Main.tscn")
var game: Node3D
var phase := "initial"

func _initialize() -> void:
    phase = "restored" if OS.get_cmdline_user_args().has("--restored") else "initial"
    call_deferred("_run")

func _run() -> void:
    game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    if phase == "initial":
        game.selected_avatar = 2
    else:
        game.selected_avatar = 0 # server must restore previous Mage.
    game._join()
    for i in range(500):
        if game.own_id != 0 and game.players.has(game.own_id) and game.player_inventories.has(game.own_id):
            break
        await process_frame
    if game.own_id == 0 or not game.player_inventories.has(game.own_id):
        _fail("cannot connect with persistent identity")
        return
    var world: Node3D = game.get_node("Eldoria_Forest")
    var resource_id := -1
    for resource in world.resources:
        if resource["kind"] == "herb":
            var p: Vector3 = resource["pos"]
            if absf(p.x+1.8)<0.12 and absf(p.z-1.5)<0.12:
                resource_id = resource["id"]
                break
    if resource_id <= 0:
        _fail("starter flower missing")
        return
    if phase == "initial":
        if game.players[game.own_id].model_kind != "Mage":
            _fail("initial Mage selection not sent to server")
            return
        if int(game.player_inventories[game.own_id].get("herb",0)) != 0:
            _fail("test started with non-empty inventory")
            return
        game._try_gather()
        for i in range(300):
            if int(game.player_inventories[game.own_id].get("herb",0)) >= 1:
                break
            await process_frame
        if int(game.player_inventories[game.own_id].get("herb",0)) != 1:
            _fail("did not obtain first herb")
            return
        if int(game.resource_remaining.get(resource_id,-1)) != 0:
            _fail("herb depletion missing")
            return
        print("PERSIST INITIAL PASS: avatar=Mage, inventory herb=1, herb depleted")
    else:
        if int(game.player_inventories[game.own_id].get("herb",0)) != 1:
            _fail("inventory not restored after server restart")
            return
        if game.players[game.own_id].model_kind != "Mage":
            _fail("server did not restore selected Mage")
            return
        if int(game.resource_remaining.get(resource_id,-1)) != 0:
            _fail("world did not restore depleted herb")
            return
        game.request_gather.rpc_id(1,resource_id) # depleted ID must not yield duplicate loot
        for i in range(25):
            await process_frame
        if int(game.player_inventories[game.own_id].get("herb",0)) != 1:
            _fail("duplicate loot after persistence restore")
            return
        print("PERSIST RESTORED PASS: Mage, herb=1, depleted plant, no duplication")
    game._disconnect()
    quit(0)

func _fail(reason: String) -> void:
    printerr("PERSIST E2E FAIL "+reason)
    quit(1)
