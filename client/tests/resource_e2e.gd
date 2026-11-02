extends SceneTree
const GAME := preload("res://Main.tscn")
var game: Node3D

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var a := OS.get_cmdline_user_args().has("--a")
    var role := "A" if a else "B"
    game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game._join()
    if not await _connected(350):
        _fail(role+" cannot connect")
        return
    var world: Node3D = game.get_node("Eldoria_Forest")
    var herb_left := -1
    var herb_right := -1
    for resource in world.resources:
        var pos: Vector3 = resource["pos"]
        if resource["kind"] == "herb" and absf(pos.x+1.8) < 0.1 and absf(pos.z-1.5)<0.1:
            herb_left = resource["id"]
        if resource["kind"] == "herb" and absf(pos.x-1.8) < 0.1 and absf(pos.z+1.5)<0.1:
            herb_right = resource["id"]
    if herb_left<0 or herb_right<0:
        _fail("starter herbs missing")
        return
    var target := herb_left if a else herb_right
    var closest: int = world.nearest_resource(game.players[game.own_id].position,2.7,game.resource_remaining)
    if closest != target:
        _fail("not next to the correct starter herb closest=%d target=%d" % [closest,target])
        return
    if game.player_inventories.has(game.own_id) and int(game.player_inventories[game.own_id].get("herb",0)) != 0:
        _fail("unexpected inventory")
        return
    for i in range(30):
        await process_frame
    game._try_gather()
    if not await _gathered(target,220):
        _fail(role+" failed to gather first herb")
        return
    print("RESOURCE OWN INVENTORY PASS "+role+" herb="+str(game.player_inventories[game.own_id]["herb"]))
    # Other peer has a different nearby flower: both should have 1 herb,
    # and both should see depletion of the exact same two resources.
    if not await _gathered(herb_left,300) or not await _gathered(herb_right,300):
        _fail(role+" other client's resource state did not replicate")
        return
    # Headless Godot uses a dummy renderer: MultiMesh GPU transforms cannot be read back here.
    # Visual depletion is asserted separately with the real OpenGL renderer.
    var mine: Dictionary = game.player_inventories.get(game.own_id,{})
    if int(mine.get("herb",0)) != 1:
        _fail(role+" own inventory incorrectly shared with other user")
        return
    # A malicious request for an unreachable or nonexistent resource must be denied.
    game.request_gather.rpc_id(1,999999)
    for i in range(35):
        await process_frame
    mine = game.player_inventories.get(game.own_id,{})
    if int(mine.get("herb",0)) != 1:
        _fail(role+" accepted invalid gather request")
        return
    print("RESOURCE AUTHORITATIVE SYNC PASS "+role)
    if a:
        # A stays connected while B disconnects and reconnects; new player
        # must receive an authoritative resource snapshot of both depleted herbs.
        if not await _await_peers(1,300):
            _fail("other client did not disconnect cleanly")
            return
        if not await _await_peers(2,370):
            _fail("late join missing")
            return
        if not await _await_peers(1,370):
            _fail("late join did not finish")
            return
        print("RESOURCE LATE JOIN OBSERVED PASS A")
    else:
        game._disconnect()
        for i in range(30):
            await process_frame
        game._join()
        if not await _connected(400):
            _fail("late-join reconnection failed")
            return
        if not await _gathered(herb_left,200) or not await _gathered(herb_right,200):
            _fail("late-join snapshot lost depleted resources")
            return
        if int(game.player_inventories[game.own_id].get("herb",0)) != 0:
            _fail("new session incorrectly inherited old inventory")
            return
        if int(game.player_choices.get(game.own_id,-1)) != game.selected_avatar:
            _fail("avatar selection lost on reconnect")
            return
        print("RESOURCE LATE JOIN SNAPSHOT PASS B")
    game._disconnect()
    quit(0)

func _await_peers(count: int,frames: int) -> bool:
    for i in range(frames):
        if game.players.size() == count:
            return true
        await process_frame
    return false

func _connected(frames: int) -> bool:
    for i in range(frames):
        if game.own_id != 0 and game.players.size()==2 and game.player_inventories.has(game.own_id):
            return true
        await process_frame
    return false

func _gathered(resource_id: int, frames: int) -> bool:
    for i in range(frames):
        if int(game.resource_remaining.get(resource_id,-1)) == 0:
            return true
        await process_frame
    return false

func _fail(reason: String) -> void:
    printerr("RESOURCE E2E FAIL: "+reason)
    quit(1)
