extends SceneTree

const GAME = preload("res://Main.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    if game._wolf_bite_ready(0,7,1000,1.0):
        _fail("first attack must announce windup")
        return
    if game._wolf_bite_ready(0,7,1549,1.0):
        _fail("attack landed before warning finished")
        return
    if not game._wolf_bite_ready(0,7,1550,1.0):
        _fail("attack must land after warning")
        return
    if game._wolf_bite_ready(1,7,2000,1.0):
        _fail("second wolf must warn independently")
        return
    if game._wolf_bite_ready(1,7,2550,1.6):
        _fail("moving out of range must cancel bite")
        return
    if game._wolf_bite_ready(1,7,2551,1.0):
        _fail("re-entry must restart warning")
        return
    game._cancel_wolf_windup(1)
    if game._wolf_bite_ready(1,7,3200,1.0):
        _fail("chase exit must cancel a prepared attack")
        return
    if game._wolf_bite_ready(1,7,3700,1.0):
        _fail("cancelled attack may not land inside the renewed windup")
        return
    if not game._wolf_bite_ready(1,7,3750,1.0):
        _fail("renewed windup should eventually permit bite")
        return
    game.wolf_windups.clear()
    if game._wolf_bite_ready(0,7,4000,1.0) or game._wolf_bite_ready(1,7,4000,1.0):
        _fail("wolves bypassed initial warning")
        return
    if game._wolf_bite_ready(2,7,4000,1.0) or game.wolf_windups.has(2):
        _fail("third wolf should circle instead of preparing simultaneous attack")
        return
    game._cancel_wolf_windup(0)
    if game._wolf_bite_ready(2,7,4200,1.0) or not game.wolf_windups.has(2):
        _fail("third wolf should begin warning after attack slot becomes available")
        return
    print("TASK076 WOLF WINDUP PASS delayed hit, independent enemies, dodge cancels")
    quit(0)

func _fail(message: String) -> void:
    printerr("TASK076 WOLF WINDUP FAIL: "+message)
    quit(1)