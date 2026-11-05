extends SceneTree
const GAME := preload("res://Main.tscn")
const A := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
const B := "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game.is_websocket_host = true
    game._host()
    game.set_physics_process(false)
    if game.own_id == 0:
        _fail("host not started")
        return
    if OS.get_cmdline_user_args().has("--restored"):
        if game.persistent_profiles.size() != 2:
            _fail("expected exactly two profiles after restart")
            return
        var a: Dictionary = game.persistent_profiles.get(A,{})
        var b: Dictionary = game.persistent_profiles.get(B,{})
        if a.is_empty() or b.is_empty():
            _fail("one identity missing")
            return
        if int(a["inventory"].get("wooden_staff",0)) != 1 or str(a["equipment"].get("main_hand","")) != "wooden_staff" or int(a["skills"].get("magic",0)) != 7:
            _fail("mage inventory/equipment/progress did not persist")
            return
        if int(b["inventory"].get("shield",0)) != 1 or str(b["equipment"].get("off_hand","")) != "shield" or int(b["skills"].get("defense",0)) != 5:
            _fail("knight inventory/equipment/progress did not persist")
            return
        if int(a["inventory"].get("shield",0)) > 0 or int(b["inventory"].get("wooden_staff",0)) > 0:
            _fail("private inventories leaked between players")
            return
        print("TASK081 TWO PROFILES RESTORED PASS distinct inventory, equipment, XP after restart")
    else:
        var mage: int = game.own_id
        var knight := 8833
        game._spawn(knight,Vector3(2,1,0),0)
        game.player_health[knight] = 100
        game.player_inventories[mage] = game._empty_inventory()
        game.player_inventories[knight] = game._empty_inventory()
        game.player_inventories[mage]["wooden_staff"] = 1
        game.player_inventories[knight]["shield"] = 1
        game.player_identity_keys[mage] = A
        game.player_identity_keys[knight] = B
        game.player_choices[mage] = 2
        game.player_choices[knight] = 0
        game.player_skills[mage] = game._empty_skills()
        game.player_skills[knight] = game._empty_skills()
        game.persistent_profiles[A] = {"avatar":2,"inventory":game.player_inventories[mage].duplicate(true),"skills":game._empty_skills(),"equipment":{"main_hand":"staff","off_hand":"unarmed","chest":"unarmed"}}
        game.persistent_profiles[B] = {"avatar":0,"inventory":game.player_inventories[knight].duplicate(true),"skills":game._empty_skills(),"equipment":{"main_hand":"unarmed","off_hand":"unarmed","chest":"unarmed"}}
        if not game._equip_combat_on_server(mage,"wooden_staff") or not game._equip_offhand_on_server(knight,true):
            _fail("equipping independent heroes failed")
            return
        if not game._award_skill_xp(mage,"magic",7) or not game._award_skill_xp(knight,"defense",5):
            _fail("awarding independent XP failed")
            return
        print("TASK081 TWO PROFILES INITIAL PASS distinct inventories, equipment and XP saved")
    game._disconnect()
    quit(0)
func _fail(message: String) -> void:
    printerr("TASK081 TWO PROFILES FAIL: " + message)
    quit(1)