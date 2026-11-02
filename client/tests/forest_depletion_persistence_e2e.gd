extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var second: bool = OS.get_cmdline_user_args().has("--restored")
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game._host()
    if game.own_id==0:
        _fail("cannot start persistent test world")
        return
    var world: Node3D = game.get_node("Eldoria_Forest")
    var tree: Dictionary = {}
    var grass: Dictionary = {}
    for resource in world.resources:
        if resource["kind"]=="wood" and tree.is_empty():
            tree=resource
        if str(resource["group"]).begins_with("Grass_") and grass.is_empty():
            grass=resource
    if tree.is_empty() or grass.is_empty():
        _fail("tree or grass missing")
        return
    if second:
        if int(game.resource_remaining.get(tree["id"],-1))!=0 or int(game.resource_remaining.get(grass["id"],-1))!=0:
            _fail("reloaded world did not remember exhausted tree and grass")
            return
        if world.obstacle_active[tree["obstacle_id"]]:
            _fail("invisible tree collider returned after reload")
            return
        print("DEPLETION RESTORED PASS: felled tree, removed collider and harvested grass")
        game._disconnect()
        quit(0)
        return
    game.players[game.own_id].position = tree["pos"] + Vector3(1.8,1.0,0)
    for i in range(4):
        if not game._gather_on_server(game.own_id,tree["id"]):
            _fail("gather tree failed iteration "+str(i)+" remaining="+str(game.resource_remaining.get(tree["id"],-1))+" elapsed="+str(Time.get_ticks_msec()-int(game.last_gather_at.get(game.own_id,0)))+" distance="+str(Vector2(game.players[game.own_id].position.x,game.players[game.own_id].position.z).distance_to(Vector2(tree["pos"].x,tree["pos"].z))))
            return
        OS.delay_msec(310) # real monotonic cooldown; headless simulation time runs faster
    if int(game.resource_remaining.get(tree["id"],-1))!=0 or world.obstacle_active[tree["obstacle_id"]]:
        _fail("exhausted tree did not unblock movement")
        return
    var pos: Vector3 = grass["pos"]
    game.players[game.own_id].position = Vector3(pos.x,world.height_at(pos.x,pos.z)+1,pos.z)
    if not game._gather_on_server(game.own_id,grass["id"]):
        _fail("could not gather grass")
        return
    if int(game.resource_remaining.get(grass["id"],-1))!=0:
        _fail("grass not depleted")
        return
    print("DEPLETION INITIAL PASS: 4 wood removed trunk, grass collected, state saved")
    game._disconnect()
    quit(0)
func _fail(message: String) -> void:
    printerr("DEPLETION PERSISTENCE FAIL: "+message)
    quit(1)
