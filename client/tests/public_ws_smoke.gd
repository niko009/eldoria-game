extends SceneTree
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
        if game.own_id != 0 and game.players.has(game.own_id):
            print("PUBLIC WSS SMOKE PASS id=%d" % game.own_id)
            game._disconnect()
            quit(0)
            return
        await process_frame
    printerr("PUBLIC WSS SMOKE FAIL info=%s status=%d" % [game.info.text,game.peer.get_connection_status()])
    quit(1)
