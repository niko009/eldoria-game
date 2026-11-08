extends SceneTree
const GAME := preload("res://Main.tscn")
const POLICY := preload("res://coop_revive_policy.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game.is_websocket_host = true
    game._host()
    game.set_physics_process(false)
    if game.own_id <= 0:
        _fail("host not ready");return
    var host: int = game.own_id
    var ally := 9001
    game.wolf_alive = true # Deterministic combat damage authorization.
    if not game._damage_player_on_server(host,500):
        _fail("solo death failed");return
    if game.player_downed_until.has(host) or int(game.player_respawn_at.get(host,0))-Time.get_ticks_msec() > 4500:
        _fail("solo death must retain four-second respawn");return
    game.player_health[host] = 100
    game.player_respawn_at.erase(host)
    var world = game.get_node("Eldoria_Forest")
    game.players[host].position = Vector3(0,world.height_at(0,0)+1,0)
    game._spawn(ally,Vector3(1.6,world.height_at(1.6,0)+1,0),0)
    game.player_health[ally] = 100
    if not game._damage_player_on_server(ally,500):
        _fail("duo death failed");return
    var down_until := int(game.player_downed_until.get(ally,0))
    if down_until <= Time.get_ticks_msec()+11500 or not game.downed_peers.has(ally):
        _fail("duo did not open downed window");return
    # A camp building between rescuer and victim must block the rescue.
    game.placed_buildings[9998] = {"kind":"tent","x":0.8,"z":0.0}
    if game._revive_hold_on_server(host,ally,true):
        _fail("rescue through tent accepted");return
    game.placed_buildings.erase(9998)
    if not game._revive_hold_on_server(host,ally,true):
        _fail("first hold failed; check distance/line of sight");return
    var started := int(game.revive_holds[host]["started"])
    game._tick_revive_holds(started+POLICY.REVIVE_HOLD_MS-1)
    if int(game.player_health[ally]) != 0:
        _fail("early rescue accepted");return
    game._tick_revive_holds(started+POLICY.REVIVE_HOLD_MS)
    if int(game.player_health[ally]) != POLICY.REVIVE_HEALTH or game.player_respawn_at.has(ally) or game.player_downed_until.has(ally):
        _fail("rescue did not restore health and cancel respawn");return
    game._tick_revive_holds(started+POLICY.REVIVE_HOLD_MS+1)
    if int(game.player_health[ally]) != POLICY.REVIVE_HEALTH:
        _fail("duplicate rescue");return
    # Moving the rescuer interrupts a hold.
    game.player_health[ally] = 0
    game.player_downed_until[ally] = Time.get_ticks_msec()+12000
    game.player_respawn_at[ally] = int(game.player_downed_until[ally])
    game.players[host].position = Vector3(0,world.height_at(0,0)+1,0)
    if not game._revive_hold_on_server(host,ally,true):
        _fail("second hold failed");return
    started = int(game.revive_holds[host]["started"])
    game.players[host].position += Vector3(0.8,0,0)
    game._tick_revive_holds(started+POLICY.REVIVE_HOLD_MS+1)
    if int(game.player_health[ally]) != 0 or game.revive_holds.has(host):
        _fail("movement interruption failed");return
    # Expired targets and invalid IDs must never enter a hold session.
    game.player_downed_until[ally] = Time.get_ticks_msec()-1
    if game._revive_hold_on_server(host,ally,true) or game._revive_hold_on_server(host,host,true):
        _fail("expired/self revive accepted");return
    print("TASK095 SERVER REVIVE PASS solo 4s, coop 12s, hold 1799/1800, no dup, interruption, expiry")
    game._disconnect()
    quit(0)

func _fail(why: String) -> void:
    printerr("TASK095 SERVER REVIVE FAIL: "+why)
    quit(1)
