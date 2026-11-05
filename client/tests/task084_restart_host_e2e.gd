extends SceneTree
const GAME = preload("res://Main.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var restored := OS.get_cmdline_user_args().has("--restored")
    var game = GAME.instantiate()
    root.add_child(game)
    for i in range(700):
        await process_frame
        if game.players.size() == 2:
            break
    if game.players.size() != 2 or game.player_identity_keys.size() != 2:
        _fail("two authenticated WebSocket players not connected")
        return
    var mage := -1
    var knight := -1
    for id in game.players:
        if game.player_choices[id] == 2:
            mage = id
        elif game.player_choices[id] == 0:
            knight = id
    if mage < 0 or knight < 0 or mage == knight:
        _fail("distinct player classes missing")
        return
    if restored:
        if game.player_inventories[mage].get("wooden_staff",0) != 1 or game.equipped_combat[mage] != "wooden_staff" or game.player_skills[mage].get("magic",0) != 9:
            _fail("mage profile not restored")
            return
        if game.player_inventories[knight].get("shield",0) != 1 or game.equipped_offhand[knight] != "shield" or game.player_skills[knight].get("defense",0) < 5 or game.player_skills[knight].get("spear",0) != 2:
            _fail("knight profile not restored")
            return
        print("TASK084 HOST RESTORED PASS independent equipment, inventory and skills")
    else:
        game.player_inventories[mage]["wooden_staff"] = 1
        game.player_inventories[knight]["shield"] = 1
        game.player_inventories[knight]["spear"] = 1
        game.persistent_profiles[game.player_identity_keys[mage]]["inventory"] = game.player_inventories[mage].duplicate(true)
        game.persistent_profiles[game.player_identity_keys[knight]]["inventory"] = game.player_inventories[knight].duplicate(true)
        if not game._equip_combat_on_server(mage,"wooden_staff") or not game._equip_offhand_on_server(knight,true):
            _fail("authoritative equip failed")
            return
        if not game._award_skill_xp(mage,"magic",7) or not game._award_skill_xp(knight,"defense",5):
            _fail("authoritative skill XP failed")
            return
        var world = game.get_node("Eldoria_Forest")
        var wolf_at := Vector3(1.5, world.height_at(1.5,-3.0)+0.1,-3.0)
        game.players[mage].position = Vector3(0,world.height_at(0,0)+1,0)
        game.players[knight].position = Vector3(2.5,world.height_at(2.5,0)+1,0)
        game.wolf_alive = true
        game.wolf_health = 100
        game.wolf_position = wolf_at
        game.pack_wolves.clear()
        game.hero_mana[mage] = 100.0
        var origin: Vector3 = game.players[mage].position + Vector3.UP*0.8
        var aim: Vector3 = (wolf_at + Vector3.UP*0.65-origin).normalized()
        if not game._mage_attack_on_server(mage,aim,0,-1):
            _fail("mage could not strike shared wolf")
            return
        if not game._equip_offhand_on_server(knight,false) or not game._equip_combat_on_server(knight,"spear"):
            _fail("knight could not equip co-op spear")
            return
        if not game._attack_on_server(knight,Vector3(-0.2,0,-1).normalized(),-1):
            _fail("knight could not strike shared wolf")
            return
        if int(game.player_skills[mage].get("magic",0)) != 9 or int(game.player_skills[knight].get("spear",0)) != 2 or game.wolf_health >= 100:
            _fail("co-op damage or independent XP incorrect")
            return
        if not game._equip_combat_on_server(knight,"unarmed") or not game._equip_offhand_on_server(knight,true):
            _fail("knight shield could not be restored after combat")
            return
        game.inventory_snapshot.rpc_id(mage,game.player_inventories[mage])
        game.inventory_snapshot.rpc_id(knight,game.player_inventories[knight])
        print("TASK084 HOST INITIAL PASS persisted two independent player profiles")
    for i in range(350):
        await process_frame
    quit(0)
func _fail(reason: String) -> void:
    printerr("TASK084 HOST FAIL " + reason)
    quit(1)