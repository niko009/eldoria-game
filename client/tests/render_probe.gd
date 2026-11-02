extends SceneTree
# This test MUST run in graphical OpenGL, not --headless: the dummy
# RenderingServer returns identity for all MultiMesh get_instance_transform().
const FOREST := preload("res://forest_world.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var forest: Node3D = FOREST.new()
    root.add_child(forest)
    await process_frame
    var resource: Dictionary = {}
    for item in forest.resources:
        if item["kind"] == "herb":
            resource = item
            break
    if resource.is_empty():
        _fail("herb missing")
        return
    var batch: MultiMeshInstance3D = forest._batch_nodes_by_key[resource["group"]]
    var idx: int = resource["index"]
    var original: Transform3D = forest._batch_original_transforms[resource["group"]][idx]
    var before: Transform3D = batch.multimesh.get_instance_transform(idx)
    if before.origin.distance_to(original.origin)>0.01:
        _fail("not running on real 3D renderer")
        return
    forest.set_resource_quantity(resource["id"],0)
    var after: Transform3D = batch.multimesh.get_instance_transform(idx)
    if absf(after.basis.determinant())>0.00001:
        _fail("depleted herb mesh still shown")
        return
    forest.set_resource_quantity(resource["id"],1)
    var restored: Transform3D = batch.multimesh.get_instance_transform(idx)
    if absf(restored.basis.determinant()-original.basis.determinant())>0.001:
        _fail("herb mesh not restored")
        return
    print("RESOURCE OPENGL VISUAL PASS: gather hides herb, snapshot restores original glTF MultiMesh instance")
    quit(0)

func _fail(reason: String) -> void:
    printerr("RESOURCE OPENGL FAIL: "+reason)
    quit(1)
