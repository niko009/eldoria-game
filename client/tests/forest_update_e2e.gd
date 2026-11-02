extends SceneTree
const GAME := preload("res://Main.tscn")
const UPDATER := preload("res://update_manager.gd")
var updates := 0
var statuses: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var g := GAME.instantiate()
    root.add_child(g)
    await process_frame
    var forest := g.get_node("Eldoria_Forest")
    if forest.asset_tree_count < 55 or forest.asset_detail_count < 120:
        _fail("insufficient imported forest models %s trees, %s details" % [forest.asset_tree_count,forest.asset_detail_count])
        return
    if absf(forest.height_at(0,0)) > 0.01 or absf(forest.height_at(3,0)) > 0.01:
        _fail("spawn clearing elevation changed")
        return
    if absf(forest.height_at(64,64)) < 0.2 and absf(forest.height_at(-60,25)) < 0.2:
        _fail("terrain hills were not generated")
        return
    print("FOREST LAYOUT PASS leaves=%s" % forest.tree_leaf_meshes.size())
    var manager := UPDATER.new()
    manager.current_version = "0.2.0"
    manager.updater_enabled = false
    root.add_child(manager)
    manager.update_available.connect(func(_ver: String, _notes: String) -> void: updates += 1)
    manager.update_status.connect(func(msg: String) -> void: statuses.append(msg))
    var current := '{"schema":1,"version":"0.2.0","windows":{"url":"https://bacus.dev/projects/eldoria/Eldoria-Windows-0.2.0.zip","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}'
    manager._manifest_response(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),current.to_utf8_buffer())
    if updates != 0 or statuses.is_empty():
        _fail("same version must not update")
        return
    var new_version := '{"schema":1,"version":"0.2.1","windows":{"url":"https://bacus.dev/projects/eldoria/Eldoria-Windows-0.2.1.zip","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"}}'
    manager._manifest_response(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),new_version.to_utf8_buffer())
    if updates != 1 or manager.latest_version != "0.2.1":
        _fail("new version must raise update event")
        return
    manager._manifest_response(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),new_version.replace("https://bacus.dev","https://evil.example").to_utf8_buffer())
    if updates != 1:
        _fail("manifest URL whitelist failed")
        return
    manager._manifest_response(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),new_version.replace("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","bad").to_utf8_buffer())
    if updates != 1:
        _fail("manifest checksum verification failed")
        return
    print("UPDATE MANIFEST VALIDATION PASS versions/allowlist/checksum")
    quit(0)

func _fail(reason: String) -> void:
    printerr("FOREST/UPDATE TEST FAIL " + reason)
    quit(1)
