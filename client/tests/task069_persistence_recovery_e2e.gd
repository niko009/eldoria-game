extends SceneTree
const GAME := preload("res://Main.tscn")
const Store := preload("res://postgres_world_store.gd")
const KEY := "task069-internal-only-test-secret"
const HASH := "1111111111111111111111111111111111111111111111111111111111111111"

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    var world: Node3D = game.get_node("Eldoria_Forest")
    var store = Store.new()
    if not store.configure("http://127.0.0.1:19093",KEY):
        _fail("configuration refused")
        return
    if not store.load_snapshot(world) or store.revision != 0:
        _fail("transient startup GET was not retried: "+store.last_error)
        return
    var inv = game._empty_inventory()
    inv["meat"]=5
    inv["hide"]=3
    inv["bone"]=4
    inv["leather_armor"]=1
    inv["grilled_meat"]=2
    store.profiles[HASH]={"avatar":2,"inventory":inv,"skills":{"archery":13,"spear":8,"defense":7}}
    store.buildings[10]={"kind":"campfire","x":1.0,"z":2.0}
    if not store.save_snapshot({},world) or store.revision != 1:
        _fail("lost PUT response not reconciled: "+store.last_error)
        return
    store.profiles[HASH]["inventory"]["meat"] = 6
    if not store.save_snapshot({},world) or store.revision != 2:
        _fail("normal next save after recovered 409 failed: "+store.last_error)
        return
    var reload=Store.new()
    reload.configure("http://127.0.0.1:19093",KEY)
    if not reload.load_snapshot(world) or reload.revision != 2:
        _fail("reload revision mismatch: "+reload.last_error)
        return
    for item in ["meat","hide","bone","leather_armor","grilled_meat"]:
        if int(reload.profiles[HASH]["inventory"].get(item,0)) != int(store.profiles[HASH]["inventory"].get(item,-1)):
            _fail("reload lost new inventory item: "+item)
            return
    store.profiles[HASH]["inventory"]["meat"] = 7
    if store.save_snapshot({},world) or store.revision != 2:
        _fail("unrelated concurrent change was wrongly accepted as our save")
        return
    if not store.last_error.contains("unsafe overwrite"):
        _fail("conflict was not explained: "+store.last_error)
        return
    print("TASK069 PERSISTENCE PASS startup retry, lost ACK 409 reconciliation, extended inventory, conflicting change fail-closed")
    quit(0)

func _fail(why: String) -> void:
    printerr("TASK069 PERSISTENCE FAIL: "+why)
    quit(1)
