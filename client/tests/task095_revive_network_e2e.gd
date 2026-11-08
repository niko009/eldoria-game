extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var role := "server" if OS.get_cmdline_user_args().has("--role-server") else "rescuer" if OS.get_cmdline_user_args().has("--role-rescuer") else "victim"
    var game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    if role != "server":
        game.selected_avatar = 0 if role == "rescuer" else 2
        game._join_websocket("ws://127.0.0.1:7788")
    var join_deadline := Time.get_ticks_msec()+18000
    while game.players.size() < 2 and Time.get_ticks_msec() < join_deadline:
        await process_frame
    if game.players.size() != 2:
        _fail(role,"two peers not connected");return
    var rescuer := 0
    var victim := 0
    for id in game.players:
        if int(game.player_choices.get(id,-1)) == 0:
            rescuer = int(id)
        elif int(game.player_choices.get(id,-1)) == 2:
            victim = int(id)
    if rescuer == 0 or victim == 0:
        _fail(role,"class identity not replicated");return
    if role == "server":
        # This script is authority-only; clients cannot set health.
        game.wolf_alive = true
        game.players[rescuer].position = Vector3(0,1,0)
        game.players[victim].position = Vector3(1.6,1,0)
        # Position is synced to both before damage and rescue request.
        game.correct_own_position.rpc_id(rescuer, game.players[rescuer].position)
        game.correct_own_position.rpc_id(victim, game.players[victim].position)
        game.sync_position.rpc(rescuer,game.players[rescuer].position)
        game.sync_position.rpc(victim,game.players[victim].position)
        await create_timer(0.9).timeout
        game.wolf_alive = true
        if not game._damage_player_on_server(victim,500):
            _fail(role,"damage rejected");return
        game.wolf_alive = false
        await create_timer(3.5).timeout
        if int(game.player_health.get(victim,-1)) < 30 or game.player_respawn_at.has(victim) or game.player_downed_until.has(victim):
            _fail(role,"server did not accept valid client hold");return
        print("TASK095 WSS SERVER PASS server-owned damage+revive")
    elif role == "rescuer":
        if game.own_id != rescuer:
            _fail(role,"unexpected client ID order");return
        var down_deadline := Time.get_ticks_msec()+9000
        while not game.downed_peers.has(victim) and Time.get_ticks_msec()<down_deadline:
            await process_frame
        if not game.downed_peers.has(victim):
            _fail(role,"downed snapshot not delivered");return
        if game._nearest_downed_ally()!=victim:
            _fail(role,"missing nearby revive prompt");return
        game._try_revive_hold(true)
        await create_timer(2.15).timeout
        game._try_revive_hold(false)
        var saved := Time.get_ticks_msec()+7000
        while int(game.player_health.get(victim,0)) != 30 and Time.get_ticks_msec()<saved:
            await process_frame
        if int(game.player_health.get(victim,0)) != 30 or game.downed_peers.has(victim):
            _fail(role,"rescue was not replicated");return
        print("TASK095 WSS RESCUER PASS remote hold and health replication")
        await create_timer(2.5).timeout
    else:
        if game.own_id != victim:
            _fail(role,"unexpected client ID order");return
        var down_deadline := Time.get_ticks_msec()+9000
        while int(game.player_health.get(victim,100)) != 0 and Time.get_ticks_msec()<down_deadline:
            await process_frame
        if int(game.player_health.get(victim,100)) != 0 or not game.downed_peers.has(victim):
            _fail(role,"downed health missing");return
        var saved := Time.get_ticks_msec()+7000
        while int(game.player_health.get(victim,0)) != 30 and Time.get_ticks_msec()<saved:
            await process_frame
        if int(game.player_health.get(victim,0)) != 30 or game.downed_peers.has(victim):
            _fail(role,"victim did not observe rescue");return
        print("TASK095 WSS VICTIM PASS health 0→30 by teammate")
        await create_timer(2.5).timeout
    game._disconnect()
    quit(0)
func _fail(role: String,msg:String) -> void:
    printerr("TASK095 WSS FAIL "+role+": "+msg);quit(1)
