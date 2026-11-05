extends SceneTree
const GAME := preload("res://Main.tscn")
var game: Node3D
var actions: Array[String] = []
var wolf_hit := false
var wolf_death := false
var bow_drawn := false

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    var server := OS.get_cmdline_user_args().has("--dedicated-server")
    if not server:
        game.selected_avatar = 1 if OS.get_cmdline_user_args().has("--a") else 2
        game._join_websocket("ws://127.0.0.1:7788")
    var deadline := Time.get_ticks_msec() + 15000
    while game.players.size() != 2 and Time.get_ticks_msec() < deadline:
        await process_frame
    if game.players.size() != 2:
        fail("two clients did not connect"); return
    game.set_physics_process(false)
    if server:
        await create_timer(1.0).timeout
        var ids: Array = game.players.keys()
        ids.sort()
        game.combat_visual_snapshot.rpc(ids[0], "bow")
        await create_timer(0.4).timeout
        game.combat_swing.rpc(ids[0])
        await create_timer(0.8).timeout
        game.combat_visual_snapshot.rpc(ids[1], "staff")
        game.offhand_visual_snapshot.rpc(ids[1], "shield")
        game.hero_ability_visual.rpc(ids[1], "heal")
        await create_timer(0.8).timeout
        game.hero_ability_visual.rpc(ids[0], "dash")
        game.player_hurt_visual.rpc(ids[1])
        game.wolf_snapshot.rpc(Vector3.ZERO, 60, true, Vector3.ZERO)
        await create_timer(0.5).timeout
        game.wolf_snapshot.rpc(Vector3.ZERO, 35, true, Vector3.ZERO)
        await create_timer(0.5).timeout
        game.wolf_snapshot.rpc(Vector3.ZERO, 0, false, Vector3.ZERO)
        game.health_snapshot_for.rpc(ids[1], 0)
        await create_timer(0.4).timeout
        game.health_snapshot_for.rpc(ids[1], 100)
        await create_timer(1.5).timeout
        print("TASK086 NETWORK SERVER PASS")
        game._disconnect()
        quit(0)
        return
    for actor in game.players.values():
        actor.visual_action.connect(func(clip: StringName) -> void:
            if clip != &"Interact":
                actions.append(String(clip)))
    deadline = Time.get_ticks_msec() + 4800
    while Time.get_ticks_msec() < deadline:
        await process_frame
        wolf_hit = wolf_hit or game.wolf_actor.hurt_count > 0
        wolf_death = wolf_death or game.wolf_actor.current_clip == "Death"
        for actor in game.players.values():
            if actor.combat_visual != null and actor.combat_visual.has_node("BowMotion"):
                bow_drawn = bow_drawn or actor.combat_visual.get_node("BowMotion").draw_amount > 0.5
    var expected: Array[String] = ["2H_Ranged_Shoot", "Spellcast_Shoot", "Dodge_Forward", "Hit_A", "Death_A"]
    if actions != expected or not bow_drawn or not wolf_hit or not wolf_death:
        fail("visual mismatch: %s bow=%s hit=%s death=%s" % [actions, bow_drawn, wolf_hit, wolf_death]); return
    for actor in game.players.values():
        if actor.visual_dead:
            fail("replicated respawn did not reset death pose"); return
    print("TASK086 NETWORK CLIENT PASS ", JSON.stringify(actions), " bow=true wolf_hit=true wolf_death=true")
    # Let the fixture server close first; simultaneous client closes otherwise
    # race the game's peer-disconnected announcement broadcast.
    await create_timer(2.0).timeout
    game._disconnect()
    quit(0)

func fail(message: String) -> void:
    printerr("TASK086 NETWORK FAIL: " + message)
    quit(1)
