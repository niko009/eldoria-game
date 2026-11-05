extends SceneTree

const GAME = preload("res://Main.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game.is_websocket_host = true
    game._host()
    game.set_physics_process(false)
    if game.own_id <= 0 or game.live_ui == null:
        _fail("host or UI missing")
        return
    game._update_online_players()
    if game.live_ui.hud.online_detail.text != "● 1":
        _fail("single player counter incorrect")
        return
    var ally_id := 4883
    game.spawn_remote(ally_id, Vector3(3,1,0), 2)
    if not game.players.has(ally_id) or not game.live_ui.notice.text.contains("Союзник присоединился"):
        _fail("new ally must be visible and announced")
        return
    if game.live_ui.hud.online_detail.text != "● 2":
        _fail("online player counter did not increase")
        return
    game.live_ui.notice.text = "unchanged"
    game.spawn_remote(ally_id, Vector3(3,1,0), 2)
    if game.live_ui.notice.text != "unchanged":
        _fail("duplicate spawn sent duplicate announcement")
        return
    game._on_leave(ally_id)
    if game.live_ui.hud.online_detail.text != "● 1":
        _fail("online counter did not decrease on ally departure")
        return
    game._disconnect()
    print("TASK083 ALLY JOIN FEEDBACK PASS")
    quit(0)

func _fail(reason: String) -> void:
    printerr("TASK083 ALLY JOIN FEEDBACK FAIL " + reason)
    quit(1)