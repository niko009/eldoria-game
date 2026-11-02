extends SceneTree

# Run on Godot headless. Verifies imported KayKit clips, actor root movement
# compatibility, visual pose changes and a no-mesh dedicated-server branch.
const ACTOR := preload("res://animated_actor.gd")
var tick := 0

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var bodies: Array[Node3D] = []
    for id in [1, 2, 3]:
        var actor: Node3D = ACTOR.new()
        actor.configure(id, false)
        actor.position = Vector3(3.0 * id, 1.0, 0.0)
        root.add_child(actor)
        bodies.append(actor)
        if actor.visual == null or actor.animator == null:
            _fail("missing skinned model or AnimationPlayer for peer " + str(id))
            return
        if not actor.animator.has_animation("Idle"):
            _fail("missing idle clip")
            return
        for clip in ["Walking_A", "Running_A", "Cheer"]:
            if not actor.animator.has_animation(clip):
                _fail("missing animation " + clip)
                return
        if actor.current_clip != "Idle":
            _fail("initial animation is not Idle")
            return
        if actor.visual.position.y != -1.0:
            _fail("character feet offset mismatch")
            return
        actor.set_motion(Vector3(4.0,0.0,0.0))
        if actor.current_clip != "Walking_A":
            _fail("walking clip not activated")
            return
        actor.set_motion(Vector3(9.0,0.0,0.0),true)
        if actor.current_clip != "Running_A":
            _fail("running clip not activated")
            return
        # KayKit models face +Z in their original pose. Confirm the face follows
        # actual movement instead of walking backwards on all four axes.
        for direction in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
            actor.rotation.y = atan2(direction.x, direction.z) + 0.22
            for turn in range(10):
                actor.set_motion(direction * 4.0)
            var facing: Vector3 = Vector3.BACK.rotated(Vector3.UP, actor.rotation.y)
            if facing.dot(direction) < 0.99:
                _fail("character facing away from movement id=%d, dir=%s, facing=%s" % [id,direction,facing])
                return
        actor.celebrate()
        if actor.current_clip != "Cheer":
            _fail("wave should play Cheer animation")
            return
        if actor.emote_until_msec <= Time.get_ticks_msec():
            _fail("Cheer hold interval missing")
            return
        actor.emote_until_msec = 0
        actor.set_motion(Vector3.ZERO)
        if actor.current_clip != "Idle":
            _fail("did not return to idle")
            return
    if bodies[0].model_kind == bodies[1].model_kind or bodies[1].model_kind == bodies[2].model_kind:
        _fail("player avatar variety not functioning")
        return
    var server_actor: Node3D = ACTOR.new()
    server_actor.configure(991, true)
    root.add_child(server_actor)
    if server_actor.visual != null or server_actor.animator != null:
        _fail("headless server should not instantiate visible 3D actor")
        return
    print("ANIMATED ACTOR PASS: 3 CC0 characters, idle/walk/run/cheer, correct spawn offset, headless mode")
    quit(0)

func _fail(message: String) -> void:
    printerr("ANIMATED ACTOR FAIL: " + message)
    quit(1)
