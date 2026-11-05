extends SceneTree
const GAME := preload("res://Main.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    var ui = game.live_ui
    ui.set_inventory({"herb":1,"mana_herb":2,"mana_potion":2})
    ui.set_avatar(2)
    ui.set_hero_class(2)
    ui.set_hero_mana(60)
    ui.set_health(75,100)
    if ui.state.amount("mana_potion") != 2:
        _fail("potion missing from inventory")
        return
    if not ui.state.recipe_materials_ready("mana_potion"):
        _fail("potion recipe unavailable with ingredients")
        return
    var button: Button = ui.hud.quick_buttons["mana_potion"]
    if button.disabled or not button.text.contains("×2"):
        _fail("combat potion button not available")
        return
    ui.set_hero_mana(100)
    if not button.disabled:
        _fail("potion usable at full mana")
        return
    ui.set_hero_class(0)
    ui.set_avatar(0)
    ui.set_hero_mana(60)
    if not button.disabled:
        _fail("non-mage can use mana potion")
        return
    print("TASK075 MANA POTION UI PASS inventory, recipe, combat button and disabled states")
    quit(0)

func _fail(reason: String) -> void:
    printerr("TASK075 MANA POTION UI FAIL: "+reason)
    quit(1)