extends SceneTree

# Regression E2E: two independent clients pull the same endpoint via HTTP,
# connect to the same headless Godot ENet server, then rejoin without an IP entry.
const SCENE := preload("res://Main.tscn")
var game: Node3D

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var role := "A" if OS.get_cmdline_user_args().has("--a") else "B"
    game = SCENE.instantiate()
    root.add_child(game)
    await process_frame
    if game.config_ready or not game.discovered_host.is_empty():
        _fail("endpoint must not be prepopulated")
        return
    game._fetch_server_config()
    if not await _await_discovery(280):
        _fail("HTTP server config not loaded " + role)
        return
    if game.discovered_host != "127.0.0.1" or game.discovered_port != 7777:
        _fail("unexpected endpoint %s:%s" % [game.discovered_host, game.discovered_port])
        return
    if not await _await_players(2, 420):
        _fail("two-client connection after discovery failed " + role)
        return
    print("DISCOVERY CONNECT PASS %s %s:%d" % [role, game.discovered_host, game.discovered_port])
    var mine: int = game.own_id
    var other: int = _other_id(mine)
    var start: Vector3 = game.players[mine].position
    var other_start: Vector3 = game.players[other].position
    if role == "A":
        Input.action_press("move_right")
    else:
        game.input_driver.press_direction(Vector2(-1, 0))
    for n in range(100):
        await process_frame
    if role == "A":
        Input.action_release("move_right")
    else:
        game.input_driver.release_direction(Vector2(-1, 0))
    for n in range(65):
        await process_frame
    if game.players[mine].position.distance_to(start) < 1.0:
        _fail(role + " did not move")
        return
    if game.players[other].position.distance_to(other_start) < 1.0:
        _fail(role + " did not replicate remote movement")
        return
    print("DISCOVERY MOVEMENT PASS " + role)
    game._interact()
    if not await _await_emotes(2, 260):
        _fail(role + " missing Wave action")
        return
    print("DISCOVERY WAVE PASS " + role)
    if role == "B":
        game._disconnect()
        for n in range(30):
            await process_frame
        game._fetch_server_config()
        if not await _await_players(2, 440):
            _fail(role + " cannot rediscover and reconnect")
            return
        if not game.config_ready:
            _fail("reconnect config not loaded")
            return
        game._interact()
        for n in range(110):
            await process_frame
        print("DISCOVERY REDISCOVERY PASS B")
        game._disconnect()
        quit(0)
    else:
        if not await _await_players(1, 250):
            _fail("missed B disconnect")
            return
        if not await _await_players(2, 400):
            _fail("missed B rediscovery")
            return
        other = _other_id(mine)
        if not await _await_actor_emote(other, 1, 180):
            _fail("missed Wave after rejoin")
            return
        if not await _await_players(1, 300):
            _fail("missed final disconnect")
            return
        print("DISCOVERY RECONNECT PASS A")
        quit(0)

func _await_discovery(frames: int) -> bool:
    for i in range(frames):
        if game.config_ready:
            return true
        await process_frame
    return false

func _await_players(count: int, frames: int) -> bool:
    for i in range(frames):
        if game.players.size() == count:
            return true
        await process_frame
    return false

func _await_emotes(count: int, frames: int) -> bool:
    for i in range(frames):
        if game.emote_counts.size() == count and game.emote_counts.values().min() >= 1:
            return true
        await process_frame
    return false

func _await_actor_emote(id: int, count: int, frames: int) -> bool:
    for i in range(frames):
        if int(game.emote_counts.get(id, 0)) >= count:
            return true
        await process_frame
    return false

func _other_id(mine: int) -> int:
    for id in game.players.keys():
        if id != mine:
            return id
    return -1

func _fail(message: String) -> void:
    printerr("DISCOVERY FAIL: " + message)
    quit(1)
