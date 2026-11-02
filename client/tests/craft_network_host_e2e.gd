extends SceneTree
# Isolated WS authority; run with --dedicated-server --websocket, no public server.
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    for i in range(480):
        await process_frame
        if game.players.size() == 2:
            break
    if game.players.size() != 2:
        _fail("expected 2 real remote clients")
        return
    var crafter := -1
    var observer := -1
    for id in game.players:
        if game.player_choices.get(id, -1) == 2:
            crafter = int(id)
        else:
            observer = int(id)
    if crafter < 0 or observer < 0:
        _fail("can't identify independent test players")
        return
    # The test client may still be at its spawn origin when the first
    # building snapshot arrives; pick a station near x=0, 3 and 6.
    var record := {"kind": "campfire", "x": 2.5, "z": -1.5}
    game._place_building(777, record)
    game.building_created.rpc(777, record)
    game.player_inventories[crafter] = {"wood": 4, "stone": 4, "herb": 0, "axe": 0}
    game.inventory_snapshot.rpc_id(crafter, game.player_inventories[crafter])
    print("CRAFT NETWORK SERVER GRANTED ONLY MAGE %d" % crafter)
    for i in range(300):
        await process_frame
        if game.player_inventories.get(crafter, {}).get("axe", 0) == 1:
            break
    if game.player_inventories.get(crafter, {}) != {"wood": 2, "stone": 2, "herb": 0, "axe": 1}:
        _fail("server didn't debit exactly one valid craft: " + str(game.player_inventories.get(crafter, {})))
        return
    for i in range(250):
        await process_frame
    if game.player_inventories.get(crafter, {}) != {"wood": 2, "stone": 2, "herb": 0, "axe": 1}:
        _fail("double submit spent resources again")
        return
    if game.player_inventories.get(observer, {}) != game._empty_inventory():
        _fail("unauthorized second player's inventory mutated")
        return
    if game.equipped_axes.get(observer, false):
        _fail("unowned axe was equipped on server")
        return
    if not game.equipped_axes.get(crafter, false):
        _fail("server never authorized crafter equipment")
        return
    print("CRAFT NETWORK SERVER PASS authoritative debit, duplicate guard, isolation")
    quit(0)
func _fail(message: String) -> void:
    printerr("CRAFT NETWORK SERVER FAIL " + message)
    quit(1)
