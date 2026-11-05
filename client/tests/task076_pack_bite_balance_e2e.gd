extends SceneTree

const GAME = preload("res://Main.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    if game.WOLF_BITE_DAMAGE < 6 or game.WOLF_BITE_DAMAGE > 8:
        _fail("wolf bite outside planned range")
        return
    if game.ALPHA_BITE_DAMAGE < 10 or game.ALPHA_BITE_DAMAGE > 12:
        _fail("alpha bite outside planned range")
        return
    if not game._can_pack_bite(5,1000):
        _fail("first wolf bite incorrectly blocked")
        return
    if game._can_pack_bite(5,1001):
        _fail("synchronized second pack bite allowed")
        return
    if not game._can_pack_bite(6,1001):
        _fail("another player should have independent attack window")
        return
    if not game._can_pack_bite(5,1650):
        _fail("attack window never opens again")
        return
    print("TASK076 PACK BITE BALANCE PASS damage bounds, staggered hits, independent targets")
    quit(0)

func _fail(message: String) -> void:
    printerr("TASK076 PACK BITE BALANCE FAIL: "+message)
    quit(1)