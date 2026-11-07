extends SceneTree
const WOLF := preload("res://wolf_actor.gd")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var wolf = WOLF.new()
    root.add_child(wolf)
    await process_frame
    if wolf.model == null or wolf.skin_mesh == null or wolf.animator == null:
        _fail("Quaternius GLB model/rig could not be loaded");return
    if wolf.visible:
        _fail("wolf appeared before an authoritative server snapshot");return
    var skeletons: Array[Node] = wolf.model.find_children("*","Skeleton3D",true,false)
    if skeletons.size() != 1 or skeletons[0].get_bone_count() < 35:
        _fail("wolf mesh missing true quadruped skeletal rig");return
    for name in ["Idle","Walk","Gallop","Attack","Idle_HitReact_Left","Idle_HitReact_Right","Death"]:
        if not wolf.animator.has_animation(name):
            _fail("missing imported clip: "+name);return
        if wolf.animator.get_animation(name).loop_mode != (Animation.LOOP_LINEAR if name in ["Idle","Walk","Gallop"] else Animation.LOOP_NONE):
            _fail("incorrect repeat settings for "+name);return
    wolf.update_state(Vector3.ZERO,60,true,Vector3.ZERO)
    await process_frame
    if wolf.current_clip != "Idle" or wolf.down or not wolf.visible:
        _fail("healthy wolf idle not shown");return
    wolf.update_state(Vector3(0,0,0.20),60,true,Vector3.FORWARD)
    await process_frame
    if wolf.current_clip != "Walk":
        _fail("small displacement must use Walk");return
    wolf.update_state(Vector3(0,0,0.73),60,true,Vector3.FORWARD)
    await process_frame
    if wolf.current_clip != "Gallop":
        _fail("wolf chase did not use Gallop");return
    wolf.play_bite()
    if wolf.current_clip != "Attack" or wolf.bite_count != 1:
        _fail("bite not mapped to bone-animated Attack");return
    wolf.update_state(Vector3(0,0,1.0),60,true,Vector3.FORWARD)
    await process_frame
    if wolf.current_clip != "Attack":
        _fail("movement packet interrupted Attack clip");return
    wolf.update_state(Vector3(0,0,1.0),47,true,Vector3.ZERO)
    if not wolf.current_clip.begins_with("Idle_HitReact") or wolf.hurt_count != 1 or wolf.skin_mesh.material_overlay == null:
        _fail("damage did not trigger hit animation/material overlay");return
    wolf.update_state(Vector3(0,0,1.0),47,true,Vector3.ZERO)
    if wolf.hurt_count != 1:
        _fail("duplicate snapshot triggered fake damage reaction");return
    wolf.update_state(Vector3(0,0,1.0),0,false,Vector3.ZERO)
    if not wolf.down or wolf.current_clip != "Death" or not wolf.visible or wolf.health_bar.visible:
        _fail("dead wolf must play visible Death once, with hidden health bar");return
    wolf.update_state(Vector3(0,0,1.0),0,false,Vector3.ZERO)
    if wolf.current_clip != "Death":
        _fail("repeated death snapshot restarted animation");return
    await create_timer(1.82).timeout
    if wolf.visible:
        _fail("corpse not hidden after Death sequence");return
    wolf.update_state(Vector3(2,0,1),60,true,Vector3.ZERO)
    await process_frame
    if not wolf.visible or wolf.down or wolf.current_clip != "Idle" or wolf.health_bar.visible:
        _fail("respawn failed to reset pose or hide unfocused health bar");return
    wolf.set_health_focus(true)
    if not wolf.health_bar.visible or wolf.health_text.text != "60 / 60":
        _fail("respawned target must show fresh current/max HP on focus");return
    wolf.set_health_focus(false)
    wolf.update_state(Vector3(2,0,1),0,false,Vector3.ZERO)
    wolf.update_state(Vector3(2,0,1),60,true,Vector3.ZERO)
    await create_timer(1.82).timeout
    if not wolf.visible:
        _fail("stale death timer hid newly-respawned wolf");return
    var late_wolf = WOLF.new()
    root.add_child(late_wolf)
    late_wolf.update_state(Vector3(3,0,3),0,false,Vector3.ZERO)
    if late_wolf.visible or not late_wolf.down:
        _fail("late joiner sees a phantom corpse for an already-dead wolf");return
    print("TASK061 RIGGED WOLF PASS 51-bone CC0 GLB, Idle/Walk/Gallop/Attack/HitReact/Death, cooldown, corpse and respawn")
    quit(0)
func _fail(reason: String) -> void:
    printerr("TASK061 RIGGED WOLF FAIL: "+reason)
    quit(1)
