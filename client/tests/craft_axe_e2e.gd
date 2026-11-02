extends SceneTree
const GAME := preload("res://Main.tscn")
const PERSISTENT_HASH := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var restored := OS.get_cmdline_user_args().has("--restored")
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game._host()
    if game.own_id == 0:
        _fail("could not start local craft host")
        return
    if restored:
        if not game.persistent_profiles.has(PERSISTENT_HASH):
            _fail("persistent axe profile missing")
            return
        var inv: Dictionary = game.persistent_profiles[PERSISTENT_HASH]["inventory"]
        if int(inv.get("axe",0)) != 1:
            _fail("crafted axe did not survive restart")
            return
        print("CRAFT AXE RESTORED PASS axe=1 persisted")
        game._disconnect()
        quit(0)
        return
    var id: int = game.own_id
    var world: Node3D = game.get_node("Eldoria_Forest")
    var inv := {"wood":4,"stone":4,"herb":0,"axe":0}
    game.player_inventories[id] = inv
    game.player_identity_keys[id] = PERSISTENT_HASH
    game.persistent_profiles[PERSISTENT_HASH] = {"avatar":0,"inventory":inv.duplicate(true)}
    # No nearby station must mean no crafting, even if this world has camps elsewhere.
    game.players[id].position = Vector3(60,world.height_at(60,60)+1,60)
    if game._craft_axe_on_server(id):
        _fail("crafting far from campfire was allowed")
        return
    game._place_building(999,{"kind":"campfire","x":0.0,"z":-4.0})
    game.players[id].position = Vector3(0,world.height_at(0,-4)+1,-3.5)
    if not game._craft_axe_on_server(id):
        _fail("valid stone axe craft failed")
        return
    var updated: Dictionary = game.player_inventories[id]
    if updated.get("axe",0)!=1 or updated.get("wood",-1)!=2 or updated.get("stone",-1)!=2:
        _fail("craft did not subtract exactly 2 wood and 2 stone")
        return
    if game._craft_axe_on_server(id):
        _fail("duplicate stone axe crafted")
        return
    # Upgraded axe must gather 2 wood in a single server-validated action.
    var wood: Dictionary = {}
    for entry in world.resources:
        if entry["kind"] == "wood" and int(game.resource_remaining.get(entry["id"],0)) >= 2:
            wood=entry
            break
    if wood.is_empty():
        _fail("no remaining wood to validate axe")
        return
    var pos: Vector3 = wood["pos"]
    game.players[id].position = Vector3(pos.x+1.1,pos.y+1.0,pos.z)
    var before: int = int(game.resource_remaining[wood["id"]])
    if not game._gather_on_server(id,wood["id"]):
        _fail("axe equipped but chop failed")
        return
    if int(game.resource_remaining[wood["id"]])!=before-2 or int(game.player_inventories[id]["wood"])!=4:
        _fail("axe didn't collect 2 wood per chop")
        return
    print("CRAFT AXE INITIAL PASS location/materials, one axe only, two-wood harvesting, saved transaction")
    game._disconnect()
    quit(0)
func _fail(message: String) -> void:
    printerr("CRAFT AXE FAIL: "+message)
    quit(1)
