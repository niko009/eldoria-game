extends SceneTree
const GAME := preload("res://Main.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    for frame in range(500):
        await process_frame
        if game.players.size() == 2:
            break
    if game.players.size() != 2:
        _fail("two clients did not connect")
        return
    var first := -1
    var second := -1
    for id in game.players:
        if int(game.player_choices[id]) == 2:
            first = int(id)
        else:
            second = int(id)
    if first < 0 or second < 0:
        _fail("client roles not detected")
        return
    var world: Node3D = game.get_node("Eldoria_Forest")
    game.wolf_position = Vector3(2, world.height_at(2, 0) + 0.1, 0)
    game.wolf_last_hit_at = Time.get_ticks_msec() + 60000 # isolate replication from autonomous attacks
    game.wolf_alive = true
    game.wolf_health = game.WOLF_MAX_HEALTH
    game.wolf_snapshot.rpc(game.wolf_position, game.wolf_health, true, Vector3.ZERO)
    for frame in range(560):
        await process_frame
        if game.wolf_health == 42:
            break
    if game.wolf_health != 42:
        _fail("authoritative wolf hit not accepted")
        return
    if int(game.player_skills.get(first,{}).get("magic",0)) < 2:
        _fail("mage did not receive server-authoritative magic XP")
        return
    if int(game.player_skills.get(second,{}).get("magic",0)) != 0:
        _fail("observer received another player's magic XP")
        return
    if not game._damage_player_on_server(second, 12):
        _fail("server health reduction failed")
        return
    # Knight passive: ceil(12 * 0.9) = 11 received damage.
    if game.player_health[second] != 89:
        _fail("server health incorrect: " + str(game.player_health))
        return
    # Keep alive until clients report observing the replicated wolf and HP.
    for frame in range(270):
        await process_frame
    print("COMBAT NETWORK SERVER PASS wolf hit, replicated HP, separate players")
    quit(0)

func _fail(reason: String) -> void:
    printerr("COMBAT NETWORK SERVER FAIL " + reason)
    quit(1)
