extends SceneTree
const ACTOR := preload("res://animated_actor.gd")
const FX := preload("res://visual_fx/effect_pool.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var actor = ACTOR.new()
    actor.configure(886, false, 2)
    root.add_child(actor)
    actor.set_combat_equipped("staff")
    actor.set_offhand_equipped("shield")
    if actor.combat_visual.get_parent() == actor.offhand_visual.get_parent():
        fail("staff and shield share a hand"); return
    if not actor.combat_visual.has_node("StaffCrystal") or actor.offhand_visual.get_child_count() == 0:
        fail("mage staff + shield missing"); return
    actor.set_combat_equipped("bow")
    var bow = actor.combat_visual.get_node("BowMotion")
    actor.play_visual_event(&"bow_draw")
    await create_timer(0.18).timeout
    if bow.draw_amount < 0.9 or bow.strings.size() != 2:
        fail("string does not draw"); return
    var pool = FX.shared(actor)
    await process_frame
    pool.clear()
    actor.melee_attack()
    await create_timer(0.19).timeout
    if pool.particles.is_empty() or not pool.particles[0].arrow:
        fail("confirmed bow attack has no visual projectile"); return
    actor.set_combat_equipped("spear")
    await create_timer(0.1).timeout
    for high in [true, false]:
        FX.high_detail = high
        pool.clear()
        for i in 100:
            pool.burst("spell", Vector3.ZERO)
        pool._process(0.01)
        if pool.particles.size() != pool.limit() or pool.batch.multimesh.visible_instance_count > pool.limit():
            fail("particle budget violated"); return
        pool._process(2.0)
        if not pool.particles.is_empty():
            fail("expired effects retained"); return
    for kind in ["spell", "heal", "dash", "taunt"]:
        pool.clear()
        actor.hero_ability_animation(kind)
        if pool.particles.is_empty():
            fail("missing class effect " + kind); return
    # Changing profile immediately trims already active effects on next update.
    FX.high_detail = true
    for i in 20:
        pool.burst("hit", Vector3.ZERO)
    FX.high_detail = false
    pool._process(0.01)
    if pool.particles.size() > FX.LOW_LIMIT:
        fail("live Low switch exceeds budget"); return
    actor.free()
    print("TASK086 EFFECTS PASS: staff+shield, bow draw/projectile, switching, class effects, global High/Low caps, cleanup")
    quit(0)

func fail(message: String) -> void:
    printerr("TASK086 FAIL: " + message)
    quit(1)
