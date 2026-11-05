extends SceneTree

const GAME = preload("res://Main.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game.reconnect_enabled = true
    game._server_disconnected()
    if game.reconnect_attempts != 1 or game.reconnect_timer.is_stopped():
        _fail("connection loss did not schedule retry")
        return
    if not game.info.text.contains("повтор 1/5") or not game.reconnect_button.visible:
        _fail("retry progress or manual reconnect button not visible")
        return
    game._disconnect()
    if game.reconnect_enabled or not game.reconnect_timer.is_stopped() or game.reconnect_button.visible:
        _fail("manual disconnect did not cancel retry")
        return
    game.reconnect_enabled = true
    for attempt in range(5):
        game._schedule_reconnect("lost")
    game._schedule_reconnect("lost")
    if game.reconnect_enabled or game.reconnect_attempts != 5 or not game.info.text.contains("ПОДКЛЮЧИТЬСЯ СНОВА"):
        _fail("retry cap not enforced")
        return
    game.reconnect_timer.stop()
    print("TASK085 MOBILE RECONNECT PASS backoff, manual cancel, retry cap")
    quit(0)

func _fail(message: String) -> void:
    printerr("TASK085 MOBILE RECONNECT FAIL " + message)
    quit(1)
