extends SceneTree

const SCENE := preload("res://Main.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game := SCENE.instantiate()
    root.add_child(game)
    var overlay: CanvasLayer = game.performance_overlay
    if overlay == null or overlay.visible:
        _fail("debug overlay must start disabled")
        return
    overlay.toggle()
    for i in range(65):
        overlay._process(0.02)
    if not overlay.visible or not overlay._label.text.contains("5% low") or not overlay._label.text.contains("Memory RSS: нет данных"):
        _fail("debug metrics missing")
        return
    overlay.toggle()
    if overlay.visible:
        _fail("debug overlay did not turn off")
        return
    print("TASK026V DIAGNOSTICS PASS")
    quit(0)

func _fail(reason: String) -> void:
    printerr("TASK026V DIAGNOSTICS FAIL: " + reason)
    quit(1)
