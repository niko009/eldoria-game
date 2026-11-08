extends SceneTree
# GP-01: authoritative arrow inventory, UI snapshots, cooldown, zero-stock and
# same identity after a real JSON-backed host restart. No physical Android claim.
const GAME := preload("res://Main.tscn")
const IDENTITY := "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var restored := OS.get_cmdline_user_args().has("--restored")
    var game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game.is_websocket_host = true
    game._host()
    game.set_physics_process(false)
    var id: int = game.own_id
    if id <= 0:
        _fail("host missing");return
    if restored:
        var profile: Dictionary = game.persistent_profiles.get(IDENTITY,{})
        if profile.is_empty() or int(profile["inventory"].get("arrow",-1)) != 0 or int(profile["inventory"].get("bow",-1)) != 1:
            _fail("restart forgot used arrows");return
        print("TASK087 FIVE ARROWS RESTART PASS exactly zero arrows after restart")
        game._disconnect()
        quit(0);return
    game.player_choices[id] = 1
    game.player_inventories[id] = game._empty_inventory()
    game.player_inventories[id]["bow"] = 1
    game.player_inventories[id]["arrow"] = 5
    game.equipped_combat[id] = "bow"
    game.player_identity_keys[id] = IDENTITY
    game.persistent_profiles[IDENTITY] = {"avatar":1,"inventory":game.player_inventories[id].duplicate(true),"skills":game._empty_skills(),"equipment":{"main_hand":"bow","off_hand":"unarmed","chest":"unarmed"}}
    game.combat_equip_snapshot("bow")
    game.inventory_snapshot(game.player_inventories[id])
    if game.live_ui.state.amount("arrow") != 5 or not game._save_world_state():
        _fail("initial five-arrow snapshot failed");return
    for expected in [4,3,2,1,0]:
        game.last_attack_at.erase(id) # Simulate waiting past 650ms between shots.
        game._bow_attack_on_server(id,Vector3.FORWARD)
        var server_count := int(game.player_inventories[id]["arrow"])
        var hud_count := int(game.live_ui.state.amount("arrow"))
        if server_count != expected or hud_count != expected:
            _fail("arrow count diverged expected=%d server=%d hud=%d" % [expected,server_count,hud_count]);return
        # A rapid duplicate attack request must not spend any extra arrow.
        game._bow_attack_on_server(id,Vector3.FORWARD)
        if int(game.player_inventories[id]["arrow"]) != expected:
            _fail("duplicate shot consumed arrow");return
    game.last_attack_at.erase(id)
    if game._bow_attack_on_server(id,Vector3.FORWARD) or int(game.player_inventories[id]["arrow"]) != 0:
        _fail("zero-stock shot accepted");return
    print("TASK087 FIVE ARROWS INITIAL PASS 5→4→3→2→1→0 server+HUD, duplicate and zero protected")
    game._disconnect()
    quit(0)
func _fail(message:String) -> void:
    printerr("TASK087 FIVE ARROWS FAIL: "+message);quit(1)
