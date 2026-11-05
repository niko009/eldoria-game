extends SceneTree
const ACTOR := preload("res://animated_actor.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for choice in 3:
        var actor = ACTOR.new()
        actor.configure(800 + choice, false, choice)
        root.add_child(actor)
        var origin: Transform3D = actor.transform
        for event in actor.VISUAL_EVENTS.EVENTS:
            actor.play_visual_event(&"idle")
            if not actor.play_visual_event(event):
                fail("event rejected: " + event); return
            actor.animator.advance(0.1)
            if not actor.animator.has_animation(actor.current_clip):
                fail("missing clip: " + event); return
        actor.play_visual_event(&"death")
        actor.emote_until_msec = 0
        actor.set_motion(Vector3.RIGHT)
        actor._process(1.0)
        if actor.current_clip != "Death_A" or actor.position != origin.origin:
            fail("death interrupted or presentation moved authority root"); return
        actor.play_visual_event(&"idle")
        actor.set_motion(Vector3.FORWARD * 7)
        actor.melee_attack()
        actor.emote_until_msec = 0
        actor._process(0.01)
        if actor.current_clip != "Running_A":
            fail("action failed to resume recent locomotion"); return
        if actor.play_visual_event(&"unknown"):
            fail("unknown event accepted"); return
        actor.free()
    var dedicated = ACTOR.new()
    dedicated.configure(900, true, 0)
    root.add_child(dedicated)
    if dedicated.play_visual_event(&"cast") or dedicated.visual != null:
        fail("dedicated server created visuals"); return
    dedicated.free()
    print("TASK086 EVENTS PASS: all events, three rigs, death hold, locomotion recovery, dedicated guard")
    quit(0)

func fail(message: String) -> void:
    printerr("TASK086 FAIL: " + message)
    quit(1)
