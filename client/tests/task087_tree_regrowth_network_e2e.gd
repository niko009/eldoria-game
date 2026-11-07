extends SceneTree
const GAME := preload("res://Main.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var args := OS.get_cmdline_user_args()
    var server := args.has("--role-server")
    var game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    if not server:
        game._join_websocket("ws://127.0.0.1:7788")
    var world = game.get_node("Eldoria_Forest")
    var tree: Dictionary = {}
    for entry in world.resources:
        if entry["kind"] == "wood" and Vector2(entry["pos"].x,entry["pos"].z).length() > 12:
            tree = entry
            break
    if tree.is_empty():
        _fail("no remote tree")
        return
    var id := int(tree["id"])
    var full := int(tree["amount"])
    if server:
        var join_deadline := Time.get_ticks_msec() + 16000
        while Time.get_ticks_msec() < join_deadline:
            await process_frame
            if game.players.size() >= 2:
                break
        if game.players.size() != 2:
            _fail("two clients did not connect")
            return
        game.resource_remaining[id] = 0
        world.set_resource_quantity(id,0)
        var now := int(Time.get_unix_time_from_system())
        game.tree_regrowth_at[id] = now - 1
        if not game._save_world_state():
            _fail("server could not persist depletion/deadline")
            return
        for peer_id in game.connected_peers:
            game.resource_changed.rpc_id(int(peer_id),id,0)
        await create_timer(0.9).timeout
        if game._tick_tree_regrowth(now) != 1 or game.resource_remaining[id] != full:
            _fail("authoritative regrowth failed")
            return
        await create_timer(1.2).timeout
        print("TASK087 NETWORK SERVER PASS two clients and authoritative tree restore")
    else:
        var fell_deadline := Time.get_ticks_msec() + 16000
        while Time.get_ticks_msec() < fell_deadline:
            await process_frame
            if game.own_id > 0 and game.resource_remaining.get(id,full) == 0:
                break
        if game.own_id <= 0 or game.resource_remaining.get(id,full) != 0:
            _fail("client did not observe felled tree")
            return
        var regrowth_deadline := Time.get_ticks_msec() + 9000
        while Time.get_ticks_msec() < regrowth_deadline:
            await process_frame
            if int(game.resource_remaining[id]) == full:
                break
        if int(game.resource_remaining[id]) != full or (int(tree["obstacle_id"]) >= 0 and not world.obstacle_active[int(tree["obstacle_id"])]):
            _fail("client did not observe returned tree/collider")
            return
        print("TASK087 NETWORK CLIENT PASS %s received same state" % ("A" if args.has("--role-a") else "B"))
    game._disconnect()
    quit(0)

func _fail(msg: String) -> void:
    printerr("TASK087 NETWORK FAIL: "+msg)
    quit(1)
