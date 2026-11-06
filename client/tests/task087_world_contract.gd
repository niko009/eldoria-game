extends SceneTree
# The obstacle Vector2 -> String representation differs between Godot's
# Windows and Linux builds. Both fingerprints were independently measured on
# the UNMODIFIED parent revision (f32598e): resource ID hashes remain equal.
const LEGACY_OBSTACLES_LINUX := "2636180039d7af991ac0bcc353e439d434f53e0e717008d85d80c2955dc578eb"
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var world := preload("res://forest_world.gd").new()
    root.add_child(world)
    await process_frame
    var records := ""
    for entry in world.resources:
        records += "%s|%s|%s|%s|%s|%s|%s\n" % [entry.id,entry.kind,entry.pos,entry.amount,entry.group,entry.index,entry.obstacle_id]
    var obstacles := ""
    var legacy_count := world.obstacle_positions.size()
    if world.get_node_or_null("WorldDressing") != null:
        legacy_count -= 8 # two arch piers, five menhirs, one campsite waymarker.
    for i in legacy_count:
        obstacles += "%s|%s\n" % [world.obstacle_positions[i],world.obstacle_radii[i]]
    var result := {"resources":records.sha256_text(),"obstacles":obstacles.sha256_text(),"count":world.resources.size(),"obstacle_count":legacy_count}
    var fixture := "res://tests/task087_world_baseline.json"
    if "--snapshot" in OS.get_cmdline_user_args():
        var file := FileAccess.open(fixture,FileAccess.WRITE)
        file.store_string(JSON.stringify(result,"  "))
        print("TASK087 BASELINE ",result)
        quit()
        return
    var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture))
    print("TASK087 CONTRACT actual=",result," expected=",expected)
    var valid_legacy_obstacles: bool = result.obstacles == expected.obstacles or result.obstacles == LEGACY_OBSTACLES_LINUX
    if result.resources != expected.resources or not valid_legacy_obstacles or result.count != int(expected.count) or legacy_count != int(expected.obstacle_count):
        printerr("TASK087 FAIL Legacy resource/obstacle contract changed")
        quit(1)
        return
    var dressing := world.get_node("WorldDressing")
    print("TASK087 LANDMARKS ", dressing.landmarks)
    assert(dressing.landmarks.size() == 3)
    assert(dressing.batches.size() <= 12)
    var high_count := 0
    var low_count := 0
    world.apply_detail_quality(true)
    for batch in dressing.batches:
        high_count += batch.multimesh.instance_count
    world.apply_detail_quality(false)
    for batch in dressing.batches:
        if batch.visible:
            low_count += batch.multimesh.instance_count
    assert(low_count < high_count*0.4 and low_count > 100)
    for i in range(legacy_count,world.obstacle_positions.size()):
        var p: Vector2 = world.obstacle_positions[i]
        assert(world.collides_at(p), "Landmark missing collider on Low")
        for resource in world.resources:
            var at: Vector3 = resource.pos
            assert(p.distance_to(Vector2(at.x,at.z)) > world.obstacle_radii[i]+1.0, "Landmark blocks gathering")
    print("TASK087 WORLD CONTRACT PASS resources=",world.resources.size()," low=",low_count," high=",high_count," landmarks=3")
    quit()
