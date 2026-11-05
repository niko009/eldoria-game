extends SceneTree

const SAVE = preload("res://world_save.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var inv := {"shield":1,"bow":1,"spear":1,"leather_armor":1}
    if not SAVE._valid_equipment({},inv,0):
        _fail("legacy empty equipment must load")
        return
    if not SAVE._valid_equipment({"main_hand":"staff","off_hand":"shield","chest":"leather_armor"},inv,2):
        _fail("mage staff and shield should coexist")
        return
    if SAVE._valid_equipment({"main_hand":"bow","off_hand":"shield"},inv,0):
        _fail("two-handed bow must exclude shield")
        return
    if SAVE._valid_equipment({"main_hand":"staff"},inv,0):
        _fail("non-mage cannot equip staff")
        return
    if SAVE._valid_equipment({"chest":"leather_armor"},{},0):
        _fail("missing armor must not be equipped")
        return
    print("TASK072 EQUIPMENT VALIDATION PASS legacy, class, ownership and 2-hand matrix")
    quit(0)

func _fail(message: String) -> void:
    printerr("TASK072 EQUIPMENT VALIDATION FAIL: "+message)
    quit(1)