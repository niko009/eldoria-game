extends SceneTree
# Real OpenGL/Xvfb verification. Dummy headless renderer returns identity transforms.
const WORLD := preload("res://forest_world.gd")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var world: Node3D = WORLD.new()
    root.add_child(world)
    await process_frame
    var tree: Dictionary = {}
    var grass: Dictionary = {}
    for entry in world.resources:
        if entry["kind"] == "wood" and tree.is_empty():
            tree = entry
        if entry["kind"] == "herb" and str(entry["group"]).begins_with("Grass_") and grass.is_empty():
            grass = entry
    if tree.is_empty() or grass.is_empty():
        _fail("tree or gatherable grass missing")
        return
    if world.resource_by_id(301)["kind"] != "herb":
        _fail("legacy PostgreSQL resource IDs changed")
        return
    if grass["id"] <= 301:
        _fail("grass must be appended after all old IDs")
        return
    var obstacle: int = tree["obstacle_id"]
    if not world.obstacle_active[obstacle]:
        _fail("tree trunk not solid initially")
        return
    if not _visible(world,tree):
        _fail("tree mesh missing initially")
        return
    world.set_resource_quantity(tree["id"],0)
    if world.obstacle_active[obstacle] or _visible(world,tree):
        _fail("felled tree still visible or collidable")
        return
    world.set_resource_quantity(tree["id"],4)
    if not world.obstacle_active[obstacle] or not _visible(world,tree):
        _fail("tree rollback did not restore mesh/collider")
        return
    if not _visible(world,grass):
        _fail("grass mesh missing initially")
        return
    world.set_resource_quantity(grass["id"],0)
    if _visible(world,grass):
        _fail("gathered grass did not disappear")
        return
    world.set_resource_quantity(grass["id"],1)
    if not _visible(world,grass):
        _fail("grass rollback failed")
        return
    # Persisted states: a fresh deterministic world replay must remove both.
    var rebuilt: Node3D = WORLD.new()
    root.add_child(rebuilt)
    await process_frame
    rebuilt.set_resource_quantity(tree["id"],0)
    rebuilt.set_resource_quantity(grass["id"],0)
    if _visible(rebuilt,tree) or _visible(rebuilt,grass) or rebuilt.obstacle_active[obstacle]:
        _fail("restore of depleted PostgreSQL snapshot failed")
        return
    print("FOREST RESOURCE OPENGL PASS tree+grass disappear, tree collider removed, rollback and saved-state replay")
    quit(0)
func _visible(world: Node3D, entry: Dictionary) -> bool:
    var batch: MultiMeshInstance3D = world._batch_nodes_by_key[entry["group"]]
    var instance: Transform3D = batch.multimesh.get_instance_transform(entry["index"])
    return absf(instance.basis.determinant()) > 0.0001
func _fail(message: String) -> void:
    printerr("FOREST RESOURCE VISUAL FAIL: "+message)
    quit(1)
