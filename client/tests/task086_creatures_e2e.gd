extends SceneTree
const PASSIVE := preload("res://passive_actor.gd")
const WOLF := preload("res://wolf_actor.gd")
const FX := preload("res://visual_fx/effect_pool.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var pool = FX.shared(root)
    await process_frame
    for kind in ["rabbit", "deer", "rare_deer"]:
        var animal = PASSIVE.new()
        animal.setup(kind)
        root.add_child(animal)
        animal.update_state(Vector3.ZERO, 24, true, Vector3.ZERO)
        animal.update_state(Vector3.ZERO, 12, true, Vector3.ZERO)
        if animal.presentation.reaction == null:
            fail("missing hit reaction " + kind); return
        animal.update_state(Vector3.ZERO, 0, false, Vector3.ZERO)
        if animal.visible or animal.presentation.corpses.size() != 1:
            fail("missing cosmetic death or authoritative visibility " + kind); return
        animal.update_state(Vector3.ZERO, 0, false, Vector3.ZERO)
        if animal.presentation.corpses.size() != 1:
            fail("duplicate snapshot replayed death"); return
        animal.update_state(Vector3.ZERO, 24, true, Vector3.ZERO)
        await process_frame
        if not animal.visible or animal.body.rotation != Vector3.ZERO:
            fail("respawn pose not reset"); return
        animal.free()
        await process_frame
    var wolf = WOLF.new()
    root.add_child(wolf)
    wolf.update_state(Vector3.ZERO, 60, true, Vector3.RIGHT)
    var original: float = wolf.rotation.y
    wolf._process(0.016)
    if wolf.rotation.y == original or is_equal_approx(wolf.rotation.y, -PI / 2):
        fail("wolf turning snaps or never turns"); return
    var before: int = pool.emitted
    wolf._process(0.35)
    if pool.emitted <= before:
        fail("moving wolf missing ground dust"); return
    wolf.free()
    print("TASK086 CREATURES PASS: hit/death/respawn, duplicate snapshots, smooth turning and ground dust")
    quit(0)

func fail(message: String) -> void:
    printerr("TASK086 FAIL: " + message)
    quit(1)
