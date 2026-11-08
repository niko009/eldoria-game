extends SceneTree
# Functional UI contract, not physical Android screenshot/hold QA.
const MAIN := preload("res://Main.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    root.size = Vector2i(800,360)
    var game = MAIN.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var ui = game.live_ui
    if ui == null:
        _fail("live UI missing");return
    var events: Array[bool] = []
    ui.revive_hold_requested.connect(func(pressed:bool) -> void: events.append(pressed))
    ui.set_revive_available(true)
    var button = ui.hud.revive_button
    if button == null or not button.visible:
        _fail("rescue prompt missing");return
    button.button_down.emit()
    button.button_up.emit()
    if events != [true,false]:
        _fail("press/release UI signal mismatch: "+str(events));return
    button.button_down.emit()
    ui._open("inventory")
    if events != [true,false,true,false] or not ui.overlay.visible:
        _fail("opening menu did not cancel held revive");return
    ui.set_revive_available(true)
    if button.visible:
        _fail("rescue button overlays active inventory");return
    ui._close()
    ui.set_revive_available(false)
    if button.visible:
        _fail("rescue button did not hide");return
    print("TASK095 REVIVE UI PASS touch-down/up, menu cancellation, modal isolation")
    quit(0)
func _fail(msg:String) -> void:
    printerr("TASK095 REVIVE UI FAIL: "+msg);quit(1)
