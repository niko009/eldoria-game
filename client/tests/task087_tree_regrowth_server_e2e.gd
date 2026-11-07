extends SceneTree
# TASK-087.06: test server-authoritative harvest -> persistence -> expiry ->
# building safety -> regeneration -> durable state, in separate real processes.
const GAME := preload("res://Main.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var phase := "restored" if OS.get_cmdline_user_args().has("--restored") else "verified" if OS.get_cmdline_user_args().has("--verified") else "initial"
    var game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    # Use isolated WS for the scripted host: ENet UDP is unavailable in some
    # local development sandboxes and is not required for a persistence test.
    game.is_websocket_host = true
    game._host()
    if game.own_id <= 0:
        _fail("host failed")
        return
    var world = game.get_node("Eldoria_Forest")
    var tree: Dictionary = {}
    for entry in world.resources:
        if entry["kind"] == "wood" and tree.is_empty():
            tree = entry
    if tree.is_empty():
        _fail("no trees")
        return
    var id := int(tree["id"])
    var count := int(tree["amount"])
    var actor = game.players[game.own_id]
    if phase == "initial":
        actor.position = tree["pos"] + Vector3(1.6,1.0,0)
        for n in count:
            if not game._gather_on_server(game.own_id,id):
                _fail("harvest failed step=%d of %d" % [n,count])
                return
            # _gather_on_server uses an authoritative 280 ms cooldown.
            OS.delay_msec(315)
        var deadline: int = int(game.tree_regrowth_at.get(id,0))
        if deadline < int(Time.get_unix_time_from_system()) + 295 or int(game.resource_remaining[id]) != 0 or world.obstacle_active[int(tree["obstacle_id"])]:
            _fail("tree must disappear and persist future deadline")
            return
        if game._gather_on_server(game.own_id,id):
            _fail("exhausted tree duplicated wood")
            return
        actor.position = Vector3(70,1,70)
        if game._tick_tree_regrowth(deadline-1) != 0:
            _fail("regrowth before 300 seconds")
            return
        print("TASK087 REGROW INITIAL PASS depletion+deadline+299s no regrowth")
    elif phase == "restored":
        var deadline := int(game.tree_regrowth_at.get(id,0))
        if deadline <= 0 or int(game.resource_remaining.get(id,-1)) != 0:
            _fail("deadline/depletion lost on server restart")
            return
        actor.position = tree["pos"] + Vector3(0.4,1.0,0)
        if game._tick_tree_regrowth(deadline+1) != 0:
            _fail("tree regrew on top of a player")
            return
        actor.position = Vector3(70,1,70)
        game.placed_buildings[998] = {"kind":"tent","x":tree["pos"].x,"z":tree["pos"].z}
        if game._tick_tree_regrowth(deadline+1) != 0 or int(game.resource_remaining[id]) != 0:
            _fail("tree regrew inside occupied building")
            return
        game.placed_buildings.erase(998)
        # Simulate a failing durable write: quantity, obstacle and original
        # deadline must all roll back, with no multiplayer resource_changed.
        var original_path: String = game.world_store.save_path
        game.world_store.save_path = ""
        if game._tick_tree_regrowth(deadline+1) != 0 or int(game.resource_remaining[id]) != 0 or int(game.tree_regrowth_at.get(id,0)) != deadline or world.obstacle_active[int(tree["obstacle_id"])]:
            _fail("failed save resurrected uncommitted tree or lost deadline")
            return
        game.world_store.save_path = original_path
        if game._tick_tree_regrowth(deadline+1) != 1:
            _fail("tree did not return at/after deadline")
            return
        if int(game.resource_remaining[id]) != count or not world.obstacle_active[int(tree["obstacle_id"])] or game.tree_regrowth_at.has(id):
            _fail("regrowth did not restore full amount and collider")
            return
        if game._tick_tree_regrowth(deadline+1) != 0:
            _fail("duplicate regrowth event")
            return
        print("TASK087 REGROW RESTORED PASS restart+building deferral+replenishment")
    else:
        if int(game.resource_remaining.get(id,-1)) != count or game.tree_regrowth_at.has(id) or not world.obstacle_active[int(tree["obstacle_id"])]:
            _fail("post-regrowth persisted state not full")
            return
        print("TASK087 REGROW VERIFIED PASS persisted new tree after second restart")
    game._disconnect()
    quit(0)

func _fail(message: String) -> void:
    printerr("TASK087 REGROW FAIL " + message)
    quit(1)
