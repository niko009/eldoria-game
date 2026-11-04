extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game.selected_avatar = 1
    game._host()
    game.set_physics_process(false)
    var id: int = game.own_id
    var world: Node3D = game.get_node("Eldoria_Forest")
    var at := Vector3(0,world.height_at(0,0)+1,0)
    game.players[id].position=at
    game.player_health[id]=100
    game.wolf_alive=true
    game.wolf_health=60
    game.wolf_position=at+Vector3(0,0,-1.0)
    game.wolf_last_hit_at=Time.get_ticks_msec()-2000
    game.wolf_snapshot(game.wolf_position,60,true,Vector3.ZERO)
    var actor = game.wolf_actor
    if actor == null or actor.jaw == null:
        _fail("wolf mouth/rig is missing");return
    var before: int = actor.bite_count
    game._combat_server_tick(0.02)
    if game.player_health[id] >= 100 or actor.bite_count <= before:
        _fail("server-confirmed wolf bite did not animate or damage player");return
    if actor.jaw.rotation.x >= -0.1:
        _fail("bite has no visible jaw animation");return
    var damage_before: int=game.player_health[id]
    game._combat_server_tick(0.02)
    if game.player_health[id] != damage_before or actor.bite_count != before+1:
        _fail("wolf cooldown bypass duplicated bite animation");return
    game.wolf_snapshot(game.wolf_position,47,true,Vector3.ZERO)
    if actor.hurt_count != 1 or actor.fur_material.albedo_color.r < 0.65:
        _fail("wolf damage flash missing");return
    game.wolf_snapshot(game.wolf_position,47,true,Vector3.ZERO)
    if actor.hurt_count != 1:
        _fail("unchanged network snapshot restarts damage flash");return
    game.wolf_attack_visual(99)
    if actor.bite_count != before+1:
        _fail("unknown wolf identity caused animation");return
    var pack_id := 1
    var pack = game.get("pack_actors")
    var pack_actor = load("res://wolf_actor.gd").new()
    pack_actor.name="TestPackWolf"
    game.add_child(pack_actor)
    pack_actor.update_state(at+Vector3(1,0,0),60,true,Vector3.ZERO)
    pack[pack_id]=pack_actor
    game.wolf_attack_visual(pack_id)
    if pack_actor.bite_count != 1 or actor.bite_count != before+1:
        _fail("pack bite not routed to correct replicated wolf");return
    await create_timer(0.4).timeout
    if absf(actor.jaw.rotation.x) > 0.01 or absf(actor.body.position.z) > 0.01:
        _fail("jaw/lunge tween did not recover");return
    print("TASK058 WOLF REACTION PASS validated bite/cooldown, pack routing, hit flash, tween recovery")
    quit(0)
func _fail(reason: String) -> void:
    printerr("TASK058 WOLF REACTION FAIL: "+reason)
    quit(1)
