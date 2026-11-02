extends SceneTree
# Reproducible collision/LOD and batching assertions; no actual mobile FPS claim.
const SCENE := preload("res://Main.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var game: Node3D = SCENE.instantiate()
    root.add_child(game)
    await process_frame
    var forest: Node3D = game.get_node("Eldoria_Forest")
    if forest.batch_nodes.size() > 40 or forest.batch_nodes.size() < 10:
        _fail("unexpected draw batches %d" % forest.batch_nodes.size())
        return
    if forest.asset_tree_count < 60 or forest.asset_detail_count < 200:
        _fail("missing forest content")
        return
    if forest.obstacle_positions.size() < forest.asset_tree_count:
        _fail("tree collision circles not registered")
        return
    var target: Vector2 = forest.obstacle_positions[0]
    var r: float = forest.obstacle_radii[0]
    var spawn := Vector3(target.x - (r+1.15), 1.0, target.y)
    if forest.collides_at(Vector2(spawn.x,spawn.z),0.43):
        _fail("start position intersects obstacle")
        return
    var end_pos: Vector3 = forest.move_actor(spawn,Vector3(3.5,0,0))
    if end_pos.x > target.x - r - 0.42:
        _fail("passed through tree/rock: %s" % end_pos)
        return
    if forest.valid_remote_step(spawn,Vector3(target.x,1,target.y)):
        _fail("server should reject obstacle penetration")
        return
    var glide: Vector3 = forest.move_actor(spawn,Vector3(3.4,0,2.4))
    if forest.collides_at(Vector2(glide.x,glide.z),0.42):
        _fail("slide ended inside obstacle")
        return
    # Verify same blocking geometry in both visual quality settings.
    forest.apply_detail_quality(false)
    if not forest.collides_at(target):
        _fail("low graphics disabled physical colliders")
        return
    var visible_low := 0
    for batch in forest.batch_nodes:
        if batch.visible:
            visible_low += 1
    forest.apply_detail_quality(true)
    var visible_high := 0
    for batch in forest.batch_nodes:
        if batch.visible:
            visible_high += 1
    if visible_low >= visible_high:
        _fail("quality scaling did not reduce ground foliage")
        return
    var slope: Vector3 = forest.move_actor(Vector3(50,1,35),Vector3(1,0,0))
    if absf(slope.y - forest.height_at(slope.x,slope.z) - 1.0) > 0.01:
        _fail("terrain follow failed")
        return
    print("COLLISION + BATCHING PASS trees=%d blockers=%d groups=%d low_visible=%d high_visible=%d" % [forest.asset_tree_count,forest.obstacle_positions.size(),forest.batch_nodes.size(),visible_low,visible_high])
    quit(0)
func _fail(reason: String) -> void:
    printerr("COLLISION/PERF FAIL " + reason)
    quit(1)
