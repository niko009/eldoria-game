extends SceneTree
# Real OpenGL renderer is required for preview models and CPU particle checks.
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    print("VISUAL TEST START")
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game._host()
    print("VISUAL TEST HOSTED")
    var id: int = game.own_id
    if id == 0:
        _fail("could not start local world")
        return
    var visuals: Node3D = game.harvest_visuals
    if visuals == null:
        _fail("harvest visual subsystem missing")
        return
    var tree: Dictionary = {}
    for entry in game.get_node("Eldoria_Forest").resources:
        if entry["kind"] == "wood":
            tree = entry
            break
    if tree.is_empty():
        _fail("tree missing")
        return
    print("VISUAL TEST BEFORE FALL")
    if not visuals.play_tree_fall(tree["id"],game.get_node("Eldoria_Forest"),tree["pos"]+Vector3(2,0,0)):
        _fail("falling tree visual failed to start")
        return
    if visuals.falling_tree_count() != 1:
        _fail("no active falling tree")
        return
    if visuals.play_tree_fall(tree["id"],game.get_node("Eldoria_Forest"),tree["pos"]):
        _fail("duplicate tree animation not blocked")
        return
    if not visuals.play_pickup("wood",tree["pos"]) or not visuals.play_pickup("herb",tree["pos"]):
        _fail("particle effect not spawned")
        return
    if visuals.burst_count()!=2:
        _fail("CPUParticles burst missing")
        return

    print("VISUAL TEST BEFORE PREVIEW")
    game.player_inventories[id] = {"wood":8,"stone":2,"herb":2}
    game._toggle_build_preview()
    if not game.preview_enabled or game.preview_actor == null or not game.preview_valid:
        _fail("build preview did not show valid campfire")
        return
    if game.preview_actor.get_child_count()<5 or not game.preview_actor.is_preview:
        _fail("preview not drawn using real building mesh")
        return
    var first_preview: Node3D = game.preview_actor
    game.build_selector.select(1)
    game._update_build_preview()
    if game.preview_kind != "tent" or game.preview_actor == first_preview or game.preview_actor.get_child_count()<3:
        _fail("switching preview models failed")
        return
    game.player_inventories[id] = {"wood":0,"stone":0,"herb":0}
    game._update_build_preview()
    if game.preview_valid or game.preview_actor.preview_valid:
        _fail("unaffordable preview not red")
        return
    game._toggle_build_preview()
    if game.preview_enabled or game.preview_actor != null:
        _fail("preview toggle failed to clear")
        return
    print("VISUAL TEST BEFORE CLEANUP WAIT")
    await create_timer(0.32).timeout
    if visuals.falling_tree_count() != 1:
        _fail("falling tree vanished before animation completed")
        return
    var falling_pivot: Node3D = visuals._falling[tree["id"]]
    if absf(falling_pivot.quaternion.get_angle()) < 0.015:
        _fail("tree did not actually rotate while falling")
        return
    await create_timer(1.25).timeout
    print("VISUAL TEST AFTER CLEANUP WAIT")
    if visuals.falling_tree_count() != 0 or visuals.burst_count()!=0:
        _fail("transient visual effects were not removed")
        return
    print("VISUAL FEEDBACK OPENGL PASS: 3D falling tree, no duplicates, particles cleared, switchable green/red 3D placement preview")
    game._disconnect()
    quit(0)

func _fail(message: String) -> void:
    printerr("VISUAL FEEDBACK OPENGL FAIL: "+message)
    quit(1)
