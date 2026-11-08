extends SceneTree
const MAIN := preload("res://Main.tscn")
const QUESTS := preload("res://quest_progress.gd")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var game = MAIN.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var ui = game.live_ui
    if ui == null:
        _fail("live UI missing");return
    for display in [Vector2i(800,360),Vector2i(1280,720)]:
        root.size = display
        for frame in range(5): await process_frame
        for status in ["active","completed","claimed"]:
            var quests: Dictionary = QUESTS.initial()
            quests[QUESTS.ID] = {"status":status,"wood":3 if status != "active" else 1,"stone":2 if status != "active" else 0}
            ui.set_quest_progress(quests)
            for frame in range(3): await process_frame
            var hud = ui.hud
            var has_claim: bool = hud.quest_claim.visible
            var has_status: bool = hud.quest_status.visible
            if has_claim != (status == "completed") or has_status == has_claim:
                _fail("incorrect quest prompt "+status);return
            var screen: Rect2 = hud.get_global_rect()
            var label_rect: Rect2 = (hud.quest_claim if has_claim else hud.quest_status).get_global_rect()
            if not screen.encloses(label_rect):
                _fail("quest prompt outside HUD "+status+" "+str(label_rect));return
            var box: Rect2 = hud.status_panel.get_global_rect()
            if not box.encloses(label_rect):
                _fail("quest UI overflows compact status panel "+status+" "+str(box)+" "+str(label_rect));return
            var out := "user://task088-quest-%dx%d-%s.png" % [display.x,display.y,status]
            var err: int = root.get_texture().get_image().save_png(out)
            if err != OK:
                _fail("cannot capture "+out+" "+str(err));return
            print("TASK088 QUEST HUD CAPTURE PASS "+out)
    quit(0)
func _fail(msg:String) -> void:
    printerr("TASK088 QUEST HUD FAIL: "+msg);quit(1)
