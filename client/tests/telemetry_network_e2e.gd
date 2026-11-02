extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game._join()
    for i in range(460):
        if game.own_id != 0 and game.players.has(game.own_id):
            break
        await process_frame
    if game.own_id == 0 or not game.players.has(game.own_id):
        _fail("could not join dedicated Godot server")
        return
    var report := {"version":game.CLIENT_VERSION,"platform":"test","quality":"low",
        "fps_avg":47.1,"fps_low_5":24.5,"frame_p95_ms":40.8,
        "memory_mb":240,"rtt_ms":25,"samples":1700}
    game.submit_telemetry.rpc_id(1,report)
    await create_timer(0.4).timeout
    game.submit_telemetry.rpc_id(1,report) # must be rejected by 45s server cooldown
    game.submit_telemetry.rpc_id(1,{"not":"a-report"}) # must be rejected
    print("TELEMETRY NETWORK CLIENT PASS sent valid sample, duplicate, invalid sample via Godot ENet")
    game._disconnect()
    quit(0)
func _fail(reason: String) -> void:
    printerr("TELEMETRY NETWORK CLIENT FAIL "+reason)
    quit(1)
