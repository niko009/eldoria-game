extends SceneTree
# TASK-022 negative cases: no partial state on persistence errors, and
# depleted wood never becomes negative even with a 2-wood axe.
const GAME := preload("res://Main.tscn")

class RejectingStore:
    extends RefCounted
    var profiles: Dictionary = {}
    var buildings: Dictionary = {}
    var last_error := "simulated isolated storage failure"
    func save_snapshot(_resources: Dictionary, _world: Node3D) -> bool:
        return false

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game._host()
    var id: int = game.own_id
    if id == 0:
        _fail("test host didn't start")
        return
    var world: Node3D = game.get_node("Eldoria_Forest")
    var actor: Node3D = game.players[id]
    var identity := "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
    game.player_identity_keys[id] = identity
    game.player_inventories[id] = {"wood": 4, "stone": 4, "herb": 0, "axe": 0}
    game.persistent_profiles[identity] = {"avatar": 0, "inventory": game.player_inventories[id].duplicate(true)}
    game._place_building(999, {"kind": "campfire", "x": 0.0, "z": -4.0})
    actor.position = Vector3(0, world.height_at(0, -4) + 1, -3.5)
    var failing := RejectingStore.new()
    game.world_store = failing
    var before: Dictionary = game.player_inventories[id].duplicate(true)
    if game._craft_axe_on_server(id):
        _fail("craft succeeded despite failed persistence")
        return
    if game.player_inventories[id] != before or game.persistent_profiles[identity]["inventory"] != before:
        _fail("failed craft spent resources or granted axe")
        return
    game.world_store = null
    if not game._craft_axe_on_server(id):
        _fail("craft failed after persistence recovered")
        return
    if int(game.player_inventories[id].get("axe", 0)) != 1:
        _fail("axe missing after successful retry")
        return
    var resource: Dictionary
    for entry in world.resources:
        if entry["kind"] == "wood" and int(game.resource_remaining.get(entry["id"], 0)) >= 2:
            resource = entry
            break
    if resource.is_empty():
        _fail("couldn't find test wood")
        return
    var resource_id: int = int(resource["id"])
    var pos: Vector3 = resource["pos"]
    actor.position = Vector3(pos.x + 1, pos.y + 1, pos.z)
    game.world_store = failing
    var amount_before: int = int(game.resource_remaining[resource_id])
    before = game.player_inventories[id].duplicate(true)
    if game._gather_on_server(id, resource_id):
        _fail("wood was harvested despite failed persistence")
        return
    if int(game.resource_remaining[resource_id]) != amount_before or game.player_inventories[id] != before:
        _fail("failed 2-wood harvest didn't roll back both quantities")
        return
    if game.persistent_profiles[identity]["inventory"] != before:
        _fail("failed harvest left dirty persistent profile")
        return
    game.world_store = null
    game.resource_remaining[resource_id] = 1
    world.set_resource_quantity(resource_id, 1)
    # Cooldown was recorded on the failed call; reset only in this isolated test.
    game.last_gather_at.erase(id)
    if not game._gather_on_server(id, resource_id):
        _fail("last remaining wood harvesting failed")
        return
    if int(game.resource_remaining[resource_id]) != 0 or int(game.player_inventories[id]["wood"]) != int(before["wood"]) + 1:
        _fail("axe overharvested one remaining wood")
        return
    if game._craft_axe_on_server(id):
        _fail("a duplicate axe was allowed")
        return
    print("CRAFT AXE FAULTS PASS failed craft/harvest rollback, retry, last wood clamp, no duplicates")
    game._disconnect()
    quit(0)

func _fail(message: String) -> void:
    printerr("CRAFT AXE FAULTS FAIL: " + message)
    quit(1)
