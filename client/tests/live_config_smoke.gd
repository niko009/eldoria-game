extends SceneTree

# Use against an already running test host with live bacus.dev server.json.
const SCENE := preload("res://Main.tscn")
var game: Node3D

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    game = SCENE.instantiate()
    root.add_child(game)
    await process_frame
    game._fetch_server_config()
    for i in range(700):
        if game.config_ready and game.own_id != 0 and game.players.has(game.own_id):
            print("LIVE CONFIG + ENET JOIN PASS")
            game._disconnect()
            quit(0)
            return
        await process_frame
    printerr("LIVE CONFIG SMOKE FAIL: config=%s host=%s id=%d info=%s" % [game.config_ready, game.discovered_host, game.own_id, game.info.text])
    quit(1)
