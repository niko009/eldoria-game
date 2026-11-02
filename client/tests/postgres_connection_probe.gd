extends SceneTree
const FOREST := preload("res://forest_world.gd")
const STORE := preload("res://postgres_world_store.gd")
func _initialize() -> void:
    call_deferred("_probe")
func _probe() -> void:
    var forest: Node3D = FOREST.new()
    root.add_child(forest)
    await process_frame
    var db := STORE.new()
    var secret_path := OS.get_environment("ELDORIA_PG_API_KEY_FILE")
    if secret_path.is_empty() or not FileAccess.file_exists(secret_path):
        _fail("server key file unavailable")
        return
    if not db.configure(OS.get_environment("ELDORIA_PG_API_URL"),
            FileAccess.get_file_as_string(secret_path).strip_edges()):
        _fail("private API configuration invalid")
        return
    if not db.load_snapshot(forest):
        _fail("private PostgreSQL connection: " + db.last_error)
        return
    print("PRODUCTION POSTGRES PROBE PASS profiles=%d buildings=%d revision=%d" %
        [db.profiles.size(),db.buildings.size(),db.revision])
    quit(0)
func _fail(reason: String) -> void:
    printerr("PRODUCTION POSTGRES PROBE FAIL: "+reason)
    quit(1)
