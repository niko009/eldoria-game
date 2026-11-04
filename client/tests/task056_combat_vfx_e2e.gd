extends SceneTree
## Requires a real renderer (Xvfb + gl_compatibility). Do not claim PASS on headless.
const GAME := preload("res://Main.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    if DisplayServer.get_name() == "headless":
        _fail("real OpenGL renderer required")
        return
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game.selected_avatar = 1
    game._host()
    game.set_physics_process(false)
    var id: int = game.own_id
    var vfx: Node3D = game.harvest_visuals
    vfx.set_sound_enabled(false)
    var world: Node3D = game.get_node("Eldoria_Forest")
    game.players[id].position = Vector3(0,world.height_at(0,0)+1,0)
    game.wolf_position = Vector3(3,world.height_at(3,0)+0.1,0)
    game.wolf_health = 60
    game.wolf_alive = true
    game.pack_wolves.clear()
    game.player_inventories[id] = game._empty_inventory()
    game.player_inventories[id]["spear"] = 1
    game.equipped_combat[id] = "spear"
    if not game._attack_on_server(id,Vector3.RIGHT):
        _fail("the server refused an in-range aimed spear hit")
        return
    if vfx.combat_burst_count() != 1:
        _fail("no effect emitted by a server-confirmed hit")
        return
    var impact: Node3D = vfx._combat_bursts[0]
    if impact.get_node("DamageNumber").text != "-30":
        _fail("damage number does not reflect server-confirmed damage")
        return
    if impact.get_node("HitSparks").amount != 10:
        _fail("HIGH quality does not create the expected visible spark budget")
        return
    if game._attack_on_server(id,Vector3.RIGHT) or vfx.combat_burst_count() != 1:
        _fail("refused duplicate hit emitted additional visual damage")
        return
    if game.wolf_actor.model == null or game.wolf_actor.skin_mesh == null or game.wolf_actor.animator == null:
        _fail("rigged wolf model missing from combat scene")
        return
    game.wolf_actor.update_state(game.wolf_position,60,true,Vector3.FORWARD)
    await create_timer(0.1).timeout
    if game.wolf_actor.current_clip not in ["Walk", "Gallop"] or not game.wolf_actor.animator.is_playing():
        _fail("rigged wolf locomotion animation does not advance")
        return
    vfx.set_combat_detail(false)
    for i in 5:
        if not vfx.play_combat_impact("wildlife",Vector3.ZERO,20):
            _fail("bounded combat effects rejected a valid slot")
            return
    if vfx.combat_burst_count() != 6 or vfx.play_combat_impact("wolf",Vector3.ZERO,10):
        _fail("concurrent combat effects exceed safe cap")
        return
    if vfx._combat_bursts[1].get_node("HitSparks").amount != 4:
        _fail("LOW quality did not reduce particle cost")
        return
    await create_timer(0.95).timeout
    if vfx.combat_burst_count() != 0:
        _fail("expired combat effects were not cleaned up")
        return
    if vfx.play_combat_impact("invalid",Vector3.ZERO,1) or vfx.play_combat_impact("wolf",Vector3.INF,1):
        _fail("invalid combat impact payload generated effects")
        return
    vfx.play_combat_impact("training",Vector3.ZERO,0)
    if vfx._combat_bursts[0].get_node("DamageNumber").text != "ТРЕНИРОВКА":
        _fail("training dummy displays fake damage")
        return
    vfx.clear_effects()
    if vfx.combat_burst_count() != 0:
        _fail("disconnect cleanup left active combat effects")
        return
    print("TASK056 COMBAT VFX OPENGL PASS server-only damage, wolf trotting, low/high sparks, bounded cleanup")
    quit(0)

func _fail(message: String) -> void:
    printerr("TASK056 COMBAT VFX OPENGL FAIL: "+message)
    quit(1)
