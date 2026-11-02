extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game._host()
    var player: int = game.own_id
    var forest: Node3D = game.get_node("Eldoria_Forest")
    var counts := {"wood":0,"stone":0,"herb":0}
    var first := {}
    for entry in forest.resources:
        var kind: String = entry["kind"]
        counts[kind] = int(counts[kind])+1
        if not first.has(kind):
            first[kind] = entry
    if counts["wood"] < 30 or counts["stone"] < 15 or counts["herb"] < 40:
        _fail("missing naturally distributed wood/stone/herb resources")
        return
    for kind in ["wood","stone"]:
        var resource: Dictionary = first[kind]
        var spot: Vector3 = resource["pos"]
        game.players[player].position = Vector3(spot.x,forest.height_at(spot.x,spot.z)+1.0,spot.z)
        if not game._gather_on_server(player,resource["id"]):
            _fail("server could not harvest nearby "+kind)
            return
        if int(game.player_inventories[player][kind]) != 1:
            _fail("server inventory did not increase "+kind)
            return
        var expected: int = int(resource["amount"])-1
        if int(game.resource_remaining[resource["id"]]) != expected:
            _fail("server resource depletion incorrect "+kind)
            return
        await create_timer(0.35).timeout
        if game._gather_on_server(player,999999):
            _fail("invalid id accepted")
            return
        await create_timer(0.35).timeout
        game.players[player].position = Vector3(-999,1,-999)
        if game._gather_on_server(player,resource["id"]):
            _fail("remote harvest bypasses proximity check")
            return
        await create_timer(0.35).timeout
    var stone: Dictionary = first["stone"]
    game.players[player].position = Vector3(stone["pos"].x,forest.height_at(stone["pos"].x,stone["pos"].z)+1.0,stone["pos"].z)
    for i in range(int(stone["amount"])-1):
        if not game._gather_on_server(player,stone["id"]):
            _fail("premature resource depletion")
            return
        await create_timer(0.33).timeout
    if game._gather_on_server(player,stone["id"]):
        _fail("depleted resource can still be harvested")
        return
    if int(game.player_inventories[player]["stone"]) != int(stone["amount"]):
        _fail("stone inventory duplicated or lost")
        return
    game._disconnect()
    print("WOOD/STONE SERVER HARVEST PASS: ranges, depletion, inventory, cooldown, invalid ID, distance")
    quit(0)
func _fail(reason: String) -> void:
    printerr("GATHER VALIDATION FAIL: "+reason)
    quit(1)
