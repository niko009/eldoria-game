extends RefCounted
## Presentation API only. Call after an authoritative event, never to request damage.
const EVENTS := [&"idle", &"walk", &"run", &"sprint", &"attack", &"melee",
    &"hit", &"death", &"cast", &"bow_draw", &"bow_release", &"equip", &"harvest"]

static func sync_health(actor: Node3D) -> void:
    # Read the existing replicated snapshot only. No new RPC or health mutation.
    var world := actor.get_parent()
    if world == null or not world.has_method("health_snapshot_for"):
        return
    var health: Dictionary = world.get("player_health")
    if not health.has(actor.player_id):
        return
    var dead := int(health[actor.player_id]) <= 0
    if dead != actor.visual_dead:
        dispatch(actor, &"death" if dead else &"idle")

static func dispatch(actor: Node3D, event: StringName, data: Dictionary = {}) -> bool:
    if event not in EVENTS or actor.headless or actor.animator == null:
        return false
    if actor.visual_dead and event != &"idle":
        return false
    match event:
        &"idle":
            if actor.visual_dead:
                actor.airborne = false
                actor.landing_until_msec = 0
            actor.visual_dead = false
            actor.emote_until_msec = 0
            actor.set_motion(Vector3.ZERO)
        &"walk", &"run", &"sprint":
            actor.set_motion(data.get("velocity", Vector3.FORWARD * (3.0 if event == &"walk" else 7.0)), event == &"sprint")
        &"attack", &"melee", &"bow_release": actor.melee_attack()
        &"hit": actor.hit_reaction()
        &"death":
            actor.visual_dead = true
            actor._play_action_clip("Death_A", 1.1)
        &"cast": actor.hero_ability_animation(str(data.get("kind", "spell")))
        &"bow_draw":
            actor._play_action_clip("2H_Ranged_Aiming", 0.35)
            if actor.combat_visual != null and actor.combat_visual.has_node("BowMotion"):
                actor.combat_visual.get_node("BowMotion").draw()
        &"equip": actor._play_action_clip("Interact", 0.3)
        &"harvest": actor.gather(str(data.get("kind", "wood")))
    return true
