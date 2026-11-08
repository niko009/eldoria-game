extends SceneTree
const GAME := preload("res://Main.tscn")
const Q := preload("res://quest_progress.gd")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var args := OS.get_cmdline_user_args()
    var role := "server" if args.has("--role-server") else "knight" if args.has("--role-knight") else "mage"
    var game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    if role != "server":
        game.selected_avatar = 0 if role == "knight" else 2
        game._join_websocket("ws://127.0.0.1:7788")
    var deadline := Time.get_ticks_msec()+15000
    while game.players.size() < 2 and Time.get_ticks_msec()<deadline:
        await process_frame
    if game.players.size() < 2:
        _fail(role,"two peers missing");return
    game.set_physics_process(false)
    var knight := 0
    var mage := 0
    for peer_id in game.players:
        if int(game.player_choices.get(peer_id,-1)) == 0:
            knight = int(peer_id)
        elif int(game.player_choices.get(peer_id,-1)) == 2:
            mage = int(peer_id)
    if knight == 0 or mage == 0:
        _fail(role,"class identity not replicated");return
    if role == "server":
        if game.player_identity_keys.size() != 2 or game.player_identity_keys[knight] == game.player_identity_keys[mage]:
            _fail(role,"distinct identities not persisted");return
        var world = game.get_node("Eldoria_Forest")
        var resource_ids := {}
        for resource in world.resources:
            var kind: String = resource["kind"]
            if kind in ["wood","stone"] and not resource_ids.has(kind):
                resource_ids[kind] = int(resource["id"])
        if resource_ids.size() != 2:
            _fail(role,"world resources absent");return
        for step in [["wood",3],["stone",2]]:
            var kind: String = step[0]
            for i in range(int(step[1])):
                var entry: Dictionary = world.resource_by_id(resource_ids[kind])
                game.players[knight].position = entry["pos"] + Vector3.UP
                game.last_gather_at.erase(knight)
                if not game._gather_on_server(knight,resource_ids[kind]):
                    _fail(role,"gather rejected: "+kind);return
        if game.player_quests[knight][Q.ID]["status"] != "completed" or game.player_quests[mage][Q.ID]["status"] != "active":
            _fail(role,"progress leaked to stranger");return
        deadline = Time.get_ticks_msec()+9000
        while game.player_quests[knight][Q.ID]["status"] != "claimed" and Time.get_ticks_msec()<deadline:
            await process_frame
        if game.player_quests[knight][Q.ID]["status"] != "claimed":
            _fail(role,"remote claim did not reach server");return
        if int(game.player_inventories[knight]["herb"]) != 2 or int(game.player_skills[knight]["defense"]) != 5:
            _fail(role,"award mismatch");return
        if int(game.player_inventories[mage]["herb"]) != 0 or game.player_quests[mage][Q.ID]["status"] != "active":
            _fail(role,"second player received foreign reward");return
        var knight_identity: String = str(game.player_identity_keys[knight])
        await create_timer(0.8).timeout
        # Clients are free to disconnect once they receive ACK; check durable
        # profile rather than indexing a departed peer's session state.
        if int(game.persistent_profiles[knight_identity]["inventory"]["herb"]) != 2:
            _fail(role,"retry paid twice");return
        print("TASK088 WSS SERVER PASS isolated identities, progress and one award")
    elif role == "knight":
        deadline = Time.get_ticks_msec()+9000
        while not game.live_ui.hud.quest_claim.visible and Time.get_ticks_msec()<deadline:
            await process_frame
        if not game.live_ui.hud.quest_claim.visible:
            _fail(role,"quest completion not reflected in HUD");return
        game.live_ui.hud.quest_claim.pressed.emit()
        # Duplicate reliable request while first one may still be pending.
        game.live_ui.hud.quest_claim.pressed.emit()
        deadline = Time.get_ticks_msec()+8000
        while game.live_ui.state.amount("herb") < 2 and Time.get_ticks_msec()<deadline:
            await process_frame
        if game.live_ui.state.amount("herb") != 2 or game.live_ui.hud.quest_claim.visible:
            _fail(role,"claim/snapshot invalid");return
        if int(game.live_ui.hud.last_skills.get("defense",-1)) != 5:
            _fail(role,"skill XP snapshot missing");return
        print("TASK088 WSS KNIGHT PASS claim through UI, reward once, XP snapshot")
    else:
        await create_timer(2.9).timeout
        if game.live_ui.state.amount("herb") != 0 or not game.live_ui.hud.quest_status.text.contains("0/3"):
            _fail(role,"foreign quest visible or reward leaked");return
        print("TASK088 WSS MAGE PASS stranger has no quest progress or reward")
    game._disconnect()
    quit(0)
func _fail(role:String,message:String) -> void:
    printerr("TASK088 WSS FAIL "+role+": "+message);quit(1)
