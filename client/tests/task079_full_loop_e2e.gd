extends SceneTree

const GAME := preload("res://Main.tscn")
const PROFILE := "abababababababababababababababababababababababababababababababab"

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
    if id == 0:
        _fail("cannot start isolated server")
        return
    if OS.get_cmdline_user_args().has("--restored"):
        if not game.persistent_profiles.has(PROFILE):
            _fail("saved profile missing")
            return
        var saved: Dictionary = game.persistent_profiles[PROFILE]
        var inv: Dictionary = saved["inventory"]
        if int(inv.get("mana_potion",0)) != 0 or int(inv.get("mana_herb",-1)) != 0 or int(inv.get("bandage",0)) != 0:
            _fail("consumed inventory not restored")
            return
        if str(saved.get("equipment",{}).get("main_hand","")) != "wooden_staff":
            _fail("equipped staff not restored")
            return
        print("TASK079 FULL LOOP RESTORED PASS persistent inventory, crafted consumable and staff")
        game._disconnect()
        quit(0)
        return
    var world: Node3D = game.get_node("Eldoria_Forest")
    var inv: Dictionary = game._empty_inventory()
    inv["herb"] = 1
    inv["bandage"] = 1
    inv["wooden_staff"] = 1
    game.player_inventories[id] = inv
    game.player_choices[id] = 2
    game.player_identity_keys[id] = PROFILE
    game.persistent_profiles[PROFILE] = {"avatar":2,"inventory":inv.duplicate(true),"skills":game._empty_skills(),"equipment":{"main_hand":"staff","off_hand":"unarmed","chest":"unarmed"}}
    var collected := 0
    for entry in world.resources:
        if entry["kind"] != "mana_herb" or int(game.resource_remaining.get(entry["id"],0)) == 0:
            continue
        var p: Vector3 = entry["pos"]
        game.players[id].position = p + Vector3.UP
        game.last_gather_at.erase(id)
        if not game._gather_on_server(id,int(entry["id"])):
            _fail("mana herb gathering rejected")
            return
        collected += 1
        if collected == 2:
            break
    if collected != 2 or int(game.player_inventories[id].get("mana_herb",0)) != 2:
        _fail("failed to gather two mana herbs")
        return
    game._place_building(999,{"kind":"campfire","x":0.0,"z":-4.0})
    game.players[id].position = Vector3(0,world.height_at(0,-4)+1,-3.5)
    if not game._craft_consumable_on_server(id,"mana_potion"):
        _fail("mana potion crafting rejected")
        return
    if int(game.player_inventories[id]["mana_potion"]) != 1 or int(game.player_inventories[id]["mana_herb"]) != 0:
        _fail("crafting did not consume ingredients")
        return
    if not game._equip_combat_on_server(id,"wooden_staff"):
        _fail("crafted staff equip failed")
        return
    game.hero_mana[id] = 30.0
    if not game._use_consumable_on_server(id,"mana_potion") or int(game.hero_mana[id]) != 65:
        _fail("potion use failed")
        return
    game.players[id].position = Vector3(0,world.height_at(0,0)+1,0)
    game.wolf_alive = true
    game.wolf_health = 60
    game.wolf_position = Vector3(4,world.height_at(4,0)+0.1,0)
    game.pack_wolves.clear()
    game.last_attack_at.erase(id)
    var origin: Vector3 = game.players[id].position + Vector3.UP*0.8
    var aim: Vector3 = (game.wolf_position + Vector3.UP*0.65-origin).normalized()
    if not game._mage_attack_on_server(id,aim,0) or game.wolf_health >= 60:
        _fail("equipped mage attack did not damage wolf")
        return
    game.player_health[id] = 40
    if not game._use_consumable_on_server(id,"bandage") or game.player_health[id] != 80:
        _fail("bandage use failed")
        return
    print("TASK079 FULL LOOP INITIAL PASS gather, craft, equip, combat, mana, heal, save")
    game._disconnect()
    quit(0)

func _fail(reason: String) -> void:
    printerr("TASK079 FULL LOOP FAIL: " + reason)
    quit(1)