extends SceneTree
const GAME = preload("res://Main.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var mage := OS.get_cmdline_user_args().has("--mage")
    var restored := OS.get_cmdline_user_args().has("--restored")
    var game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game.selected_avatar = 2 if mage else 0
    game._join_websocket("ws://127.0.0.1:7788")
    for i in range(1100):
        await process_frame
        if game.own_id > 0 and game.players.size() == 2 and game.player_inventories.has(game.own_id):
            var item := "wooden_staff" if mage else "shield"
            if game.player_inventories[game.own_id].get(item,0) == 1:
                break
    if game.own_id <= 0 or game.players.size() != 2:
        _fail("two real clients do not see each other")
        return
    var item := "wooden_staff" if mage else "shield"
    if game.player_inventories.get(game.own_id,{}).get(item,0) != 1:
        _fail("missing authoritative inventory snapshot " + item)
        return
    if restored:
        var own_equipment: bool = game.live_ui.combat_equipment == "wooden_staff" if mage else bool(game.live_ui.shield_equipped)
        if not own_equipment:
            _fail("missing restored equipment on client")
            return
    print("TASK084 CLIENT %s %s PASS" % ["MAGE" if mage else "KNIGHT", "RESTORED" if restored else "INITIAL"])
    for i in range(240):
        await process_frame
    game._disconnect()
    quit(0)
func _fail(reason: String) -> void:
    printerr("TASK084 CLIENT FAIL " + reason)
    quit(1)