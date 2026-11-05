extends SceneTree

const GAME := preload("res://Main.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    var world = game.get_node("Eldoria_Forest")
    var found := 0
    for resource in world.resources:
        if resource["kind"] != "mana_herb":
            continue
        found += 1
        var id: int = resource["id"]
        if resource["mana_visual"] == null or not resource["mana_visual"].visible:
            _fail("mana plant is invisible before gathering")
            return
        world.set_resource_quantity(id,0)
        if resource["mana_visual"].visible:
            _fail("gathered mana plant did not disappear")
            return
        world.set_resource_quantity(id,1)
        if not resource["mana_visual"].visible:
            _fail("regenerated mana plant did not reappear")
            return
    if found < 5:
        _fail("no mana plants in shared world")
        return
    print("TASK075 MANA HERB WORLD PASS %d deterministic plants, depletion and restoration" % found)
    quit(0)

func _fail(message: String) -> void:
    printerr("TASK075 MANA HERB WORLD FAIL: " + message)
    quit(1)