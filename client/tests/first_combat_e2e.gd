extends SceneTree
# TASK-025 first combat loop: deterministic server-only checks, no DB/network.
const SCENE := preload("res://Main.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game: Node3D = SCENE.instantiate()
    root.add_child(game)
    await process_frame
    game._host()
    var id: int = game.own_id
    if id == 0 or not game.player_health.has(id) or game.player_health[id] != 100:
        _fail("missing full health after host")
        return
    if not game.wolf_alive or game.wolf_health != 60:
        _fail("wolf not spawned")
        return
    var world: Node3D = game.get_node("Eldoria_Forest")
    var old_world: Dictionary = game.placed_buildings.duplicate(true)
    var before: int = game.wolf_health
    if game._attack_on_server(id):
        _fail("distant wolf accepted an attack")
        return
    if game._attack_on_server(987654):
        _fail("missing player accepted an attack")
        return
    var at: Vector3 = game.wolf_position
    game.players[id].position = Vector3(at.x + 1, world.height_at(at.x + 1, at.z) + 1, at.z)
    if not game._attack_on_server(id):
        _fail("valid wolf hit rejected")
        return
    if game.wolf_health != before - 20:
        _fail("first strike didn't deal expected 20 damage")
        return
    if game._attack_on_server(id) or game.wolf_health != 40:
        _fail("attack cooldown bypass")
        return
    game.last_attack_at.erase(id)
    if not game._attack_on_server(id):
        _fail("second valid strike rejected")
        return
    game.last_attack_at.erase(id)
    if not game._attack_on_server(id) or game.wolf_alive or game.wolf_health != 0:
        _fail("wolf did not die after 3 strikes")
        return
    game.last_attack_at.erase(id)
    if game._attack_on_server(id):
        _fail("wolf corpse accepted extra damage")
        return
    game.wolf_respawn_at = Time.get_ticks_msec() - 1
    # The new raid lifecycle only respawns defeated wolves during night.
    game.raid.phase = "night"
    game.raid.deadline_ms = Time.get_ticks_msec() + 60000
    game._combat_server_tick(0.02)
    if not game.wolf_alive or game.wolf_health != 60:
        _fail("wolf did not respawn")
        return
    # Repeat enemy attacks while standing next to the victim: no client input.
    game.wolf_position = game.players[id].position + Vector3(0, -0.9, 0)
    # Knight now mitigates 12 damage to 11, so ten hits are needed from 100 HP.
    for attempt in range(10):
        game.wolf_last_hit_at = -100000
        game._combat_server_tick(0.02)
    if game.player_health[id] != 0 or not game.player_respawn_at.has(id):
        _fail("wolf cannot kill the player")
        return
    game.last_attack_at.erase(id)
    if game._attack_on_server(id):
        _fail("dead player could attack")
        return
    game.player_respawn_at[id] = Time.get_ticks_msec() - 1
    # Wolf stays at previous spot and may chase but cannot instantly hit origin.
    game._combat_server_tick(0.02)
    if game.player_health[id] != 100 or game.player_respawn_at.has(id):
        _fail("respawn didn't restore health")
        return
    if game.placed_buildings != old_world:
        _fail("combat mutated saved buildings")
        return
    print("COMBAT FIRST LOOP PASS 100 HP, range/cooldown, wolf kill/respawn, damage/death/player respawn, world unchanged")
    game._disconnect()
    quit(0)

func _fail(text: String) -> void:
    printerr("COMBAT FIRST LOOP FAIL " + text)
    quit(1)
