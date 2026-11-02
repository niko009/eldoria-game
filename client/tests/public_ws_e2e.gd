extends SceneTree

# Three separate processes: headless dedicated ENet host and two real Godot clients.
const SCENE := preload("res://Main.tscn")
var game: Node3D

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var role := "A" if OS.get_cmdline_user_args().has("--a") else "B"
    game = SCENE.instantiate()
    root.add_child(game)
    await process_frame
    var host_ip := OS.get_environment("ELDORIA_SERVER_IP")
    if not host_ip.is_empty():
        game.ip_input.text = host_ip
    game._join_websocket("wss://bacus.dev/eldoria/ws")
    if not await _await_players(2, 400):
        _fail(role + " initial two-client connection")
        return
    var mine: int = game.own_id
    var other: int = _other_id(mine)
    if mine == 1 or other == 1:
        _fail("headless dedicated server must not create a player avatar")
        return
    var initial: Vector3 = game.players[mine].position
    var remote_initial: Vector3 = game.players[other].position
    if absf(remote_initial.y - 1.0) > 0.01:
        _fail("incorrect remote spawn elevation")
        return

    # Camera is independent of world positions; input is camera-relative.
    game.input_driver._look(Vector2(80, -40), 0.004)
    if absf(game.input_driver.yaw) < 0.05:
        _fail("camera look input not applied")
        return
    if role == "A":
        Input.action_press("move_right")
    else:
        game.input_driver.press_direction(Vector2(-1, 0)) # simulate Android button path
    for n in range(110):
        await process_frame
    if role == "A":
        Input.action_release("move_right")
    else:
        game.input_driver.release_direction(Vector2(-1, 0))
    for n in range(70):
        await process_frame
    if game.players[mine].position.distance_to(initial) < 1.0:
        _fail(role + " own movement")
        return
    if game.players[other].position.distance_to(remote_initial) < 1.0:
        _fail(role + " remote replicated movement")
        return
    print("WEBSOCKET PROTOCOL MOVEMENT PASS " + role)

    game._interact()
    if not await _await_two_emotes(mine, other, 260):
        _fail(role + " server-broadcast interaction")
        return
    print("WEBSOCKET PROTOCOL INTERACTION PASS " + role)
    if role == "B":
        game._disconnect()
        if game.own_id != 0 or not game.players.is_empty():
            _fail("B disconnect cleanup")
            return
        for n in range(40):
            await process_frame
        game._join_websocket("wss://bacus.dev/eldoria/ws")
        if not await _await_players(2, 350):
            _fail("B reconnect to dedicated host")
            return
        mine = game.own_id
        game._interact()
        for n in range(55):
            await process_frame
        game.input_driver.press_direction(Vector2(0, 1))
        for n in range(95):
            await process_frame
        game.input_driver.release_direction(Vector2(0, 1))
        for n in range(60):
            await process_frame
        print("WEBSOCKET PROTOCOL REJOIN PASS B")
        game._disconnect()
        quit(0)
        return
    if not await _await_players(1, 250):
        _fail("A missed B disconnect")
        return
    if not await _await_players(2, 350):
        _fail("A missed B reconnect")
        return
    other = _other_id(mine)
    var p0: Vector3 = game.players[other].position
    if not await _await_emote(other, 1, 190):
        _fail("A missed B post-reconnect interaction")
        return
    for n in range(180):
        await process_frame
    if game.players[other].position.distance_to(p0) < 1.0:
        _fail("A missed B post-reconnect movement")
        return
    print("WEBSOCKET PROTOCOL REJOIN + INTERACTION PASS A")
    quit(0)

func _await_two_emotes(mine: int, other: int, frames: int) -> bool:
    for n in range(frames):
        if int(game.emote_counts.get(mine, 0)) >= 1 and int(game.emote_counts.get(other, 0)) >= 1:
            return true
        await process_frame
    return false

func _await_emote(actor_id: int, count: int, frames: int) -> bool:
    for n in range(frames):
        if int(game.emote_counts.get(actor_id, 0)) >= count:
            return true
        await process_frame
    return false

func _other_id(mine: int) -> int:
    for id in game.players.keys():
        if id != mine:
            return id
    return -1

func _await_players(count: int, frames: int) -> bool:
    for n in range(frames):
        if game.players.size() == count:
            return true
        await process_frame
    return false

func _fail(text: String) -> void:
    printerr("WEBSOCKET FAIL " + text)
    quit(1)
