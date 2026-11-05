extends SceneTree

const GAME := preload("res://Main.tscn")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game.selected_avatar = 2
    game.is_websocket_host = true
    game._host()
    game.set_physics_process(false)
    var id: int = game.own_id
    if id == 0 or not game.players.has(id):
        _fail("test host did not start")
        return
    game.player_choices[id] = 2
    game.player_inventories[id] = {"mana_potion":2,"bandage":1,"grilled_meat":0,"repair_kit":0}
    game.player_health[id] = 50
    game.hero_mana[id] = 20.0
    if not game._use_consumable_on_server(id,"mana_potion"):
        _fail("mage potion refused")
        return
    if int(game.hero_mana[id]) != 55 or int(game.player_inventories[id]["mana_potion"]) != 1:
        _fail("potion did not restore mana or decrement inventory")
        return
    if game._use_consumable_on_server(id,"mana_potion"):
        _fail("mana potion bypassed cooldown")
        return
    if not game._use_consumable_on_server(id,"bandage"):
        _fail("bandage refused")
        return
    if game.player_health[id] != 90 or game.player_inventories[id]["bandage"] != 0:
        _fail("bandage did not heal or decrement")
        return
    game.player_choices[id] = 0
    game.mana_potion_used_at.erase(id)
    if game._use_consumable_on_server(id,"mana_potion"):
        _fail("non-mage could drink mana potion")
        return
    if game.player_inventories[id]["mana_potion"] != 1:
        _fail("rejected operation changed inventory")
        return
    game.player_inventories[id]["bow"] = 1
    game.player_inventories[id]["shield"] = 1
    game.player_inventories[id]["wooden_staff"] = 1
    if game._equip_combat_on_server(id,"wooden_staff"):
        _fail("knight equipped a mage staff")
        return
    if not game._equip_offhand_on_server(id,true):
        _fail("shield equip refused")
        return
    if not game._equip_combat_on_server(id,"bow"):
        _fail("owned bow equip refused")
        return
    if game.equipped_offhand[id] != "unarmed" or game.equipped_combat[id] != "bow":
        _fail("two-handed bow did not unequip shield")
        return
    if game._equip_offhand_on_server(id,true):
        _fail("shield equipped with two-handed bow")
        return
    game.player_choices[id] = 2
    if not game._equip_combat_on_server(id,"wooden_staff"):
        _fail("mage could not equip crafted staff")
        return
    print("TASK078 SERVER ACTIONS PASS consumables, cooldown, class, bow/shield exclusion, mage staff")
    game._disconnect()
    quit(0)

func _fail(reason: String) -> void:
    printerr("TASK078 CONSUMABLE SERVER FAIL: " + reason)
    quit(1)