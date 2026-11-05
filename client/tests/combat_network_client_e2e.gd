extends SceneTree
const GAME := preload("res://Main.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var is_a := OS.get_cmdline_user_args().has("--a")
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game.selected_avatar = 2 if is_a else 0
    game._join_websocket("ws://127.0.0.1:7788")
    for frame in range(560):
        await process_frame
        if game.own_id > 0 and game.players.size() == 2 and game.wolf_alive and game.wolf_position.x < 4:
            break
    if game.own_id == 0 or game.players.size() != 2 or game.wolf_position.x > 4:
        _fail("wolf or peer snapshot missing")
        return
    # The other player may attack before this client's first HUD read.
    # Check only that an authoritative health snapshot arrived.
    for frame in range(100):
        await process_frame
        if game.live_ui != null and game.live_ui.state.health_known:
            break
    if game.live_ui == null or not game.live_ui.state.health_known:
        _fail("server health HUD missing own=" + str(game.own_id) + " dict=" + str(game.player_health) + " ui=" + str(game.live_ui != null))
        return
    if is_a:
        # The Mage has a ranged spell instead of legacy directionless punches.
        # Aim at the authoritative wolf position, not the default -Z camera.
        var origin: Vector3 = game.players[game.own_id].position+Vector3.UP*0.8
        var target: Vector3 = game.wolf_position+Vector3.UP*0.65
        game.request_mage_attack.rpc_id(1,(target-origin).normalized(),0)
        for frame in range(440):
            await process_frame
            if game.wolf_health == 42:
                break
        if game.wolf_health != 42:
            _fail("server wolf damage not replicated")
            return
    else:
        for frame in range(490):
            await process_frame
            if game.wolf_health == 42 and game.live_ui.state.health == 89:
                break
        if game.wolf_health != 42 or game.live_ui.state.health != 89:
            _fail("observer didn't receive wolf and own health updates")
            return
    print("COMBAT NETWORK CLIENT PASS " + ("A" if is_a else "B"))
    for frame in range(170):
        await process_frame
    game._disconnect()
    quit(0)

func _fail(reason: String) -> void:
    printerr("COMBAT NETWORK CLIENT FAIL " + reason)
    quit(1)
