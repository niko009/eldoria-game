extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game._join_websocket("wss://bacus.dev/eldoria/ws")
    for i in range(500):
        await process_frame
        if game.own_id != 0 and game.players.has(game.own_id):
            break
    if game.own_id == 0 or not game.players.has(game.own_id):
        _fail("no public WSS spawn")
        return
    var report := {"version":game.CLIENT_VERSION,"platform":"test",
        "quality":"low","fps_avg":48.2,"fps_low_5":30.1,
        "frame_p95_ms":33.2,"memory_mb":256,"rtt_ms":62,"samples":1200}
    game.submit_telemetry.rpc_id(1,report)
    for i in range(100):
        await process_frame
    print("PUBLIC TELEMETRY SENT PASS: connected anonymous WSS client using v"+str(game.CLIENT_VERSION))
    game._disconnect()
    quit(0)
func _fail(reason: String) -> void:
    printerr("PUBLIC TELEMETRY FAIL: "+reason)
    quit(1)
