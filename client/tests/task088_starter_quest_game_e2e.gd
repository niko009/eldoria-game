extends SceneTree
const GAME := preload("res://Main.tscn")
const QUESTS := preload("res://quest_progress.gd")
const PROFILE := "abababababababababababababababababababababababababababababababab"
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var stage := "initial"
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--phase="):
            stage = arg.substr(8)
    var game = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game.is_websocket_host = true
    game._host()
    game.set_physics_process(false)
    var id: int = game.own_id
    if id == 0:
        _fail("host did not start");return
    if stage == "initial":
        game.player_identity_keys[id] = PROFILE
        game.player_choices[id] = 0
        game.player_quests[id] = QUESTS.initial()
        game.player_inventories[id] = game._empty_inventory()
        game.player_skills[id] = game._empty_skills()
        game.persistent_profiles[PROFILE] = {"avatar":0,"quests":QUESTS.initial(),"inventory":game._empty_inventory(),"skills":game._empty_skills(),"equipment":{"main_hand":"unarmed","off_hand":"unarmed","chest":"unarmed"}}
        if not game._save_world_state():
            _fail("initial snapshot save");return
        var world = game.get_node("Eldoria_Forest")
        var gather_ids := {}
        for resource in world.resources:
            var kind: String = str(resource["kind"])
            if kind in ["wood","stone"] and not gather_ids.has(kind):
                gather_ids[kind] = int(resource["id"])
        if gather_ids.size() != 2:
            _fail("missing world resources");return
        for step in [["wood",3],["stone",2]]:
            var kind: String = step[0]
            for i in range(int(step[1])):
                var entry: Dictionary = world.resource_by_id(gather_ids[kind])
                game.players[id].position = entry["pos"] + Vector3.UP
                game.last_gather_at.erase(id)
                if not game._gather_on_server(id,gather_ids[kind]):
                    _fail("authoritative gather failed "+kind);return
        if game.player_quests[id][QUESTS.ID]["status"] != "completed":
            _fail("reward not ready");return
        if int(game.player_inventories[id]["wood"]) != 3 or int(game.player_inventories[id]["stone"]) != 2:
            _fail("inventory mismatch");return
        if game.live_ui.hud.quest_claim == null or not game.live_ui.hud.quest_claim.visible:
            _fail("quest claim UI did not render");return
        print("TASK088 INITIAL PASS: 3 wood + 2 stone server events → completed UI")
    else:
        if not game.persistent_profiles.has(PROFILE):
            _fail("profile not restored");return
        var profile: Dictionary = game.persistent_profiles[PROFILE]
        game.player_identity_keys[id] = PROFILE
        game.player_choices[id] = 0
        game.player_quests[id] = profile["quests"].duplicate(true)
        game.player_inventories[id] = profile["inventory"].duplicate(true)
        game.player_skills[id] = profile["skills"].duplicate(true)
        if stage == "claim":
            if game.player_quests[id][QUESTS.ID]["status"] != "completed":
                _fail("quest progress not restored");return
            # A synthetic save failure must roll back inventory, XP and claimed marker.
            if OS.get_environment("ELDORIA_PG_API_URL").is_empty():
                var original_path: String = game.world_store.save_path
                game.world_store.save_path = "/proc/eldoria-quest-save-blocked.json"
                var ignored: bool = game._quest_claim_on_server(id)
                game.world_store.save_path = original_path
                if ignored or game.player_quests[id][QUESTS.ID]["status"] != "completed" or int(game.player_inventories[id]["herb"]) != 0 or int(game.player_skills[id]["defense"]) != 0:
                    _fail("failed save did not roll back atomic payout");return
            if not game._quest_claim_on_server(id) or game._quest_claim_on_server(id):
                _fail("claim idempotence violated");return
            if int(game.player_inventories[id]["herb"]) != 2 or int(game.player_skills[id]["defense"]) != 5:
                _fail("claim award incorrect");return
            print("TASK088 CLAIM PASS: rollback on save error, XP+herb awarded exactly once")
        elif stage == "verify":
            if game.player_quests[id][QUESTS.ID]["status"] != "claimed" or int(game.player_inventories[id]["herb"]) != 2 or int(game.player_skills[id]["defense"]) != 5:
                _fail("post-restart rewards lost");return
            if game._quest_claim_on_server(id):
                _fail("duplicate payout after restart");return
            print("TASK088 VERIFY PASS: reward persisted after restart, no double claim")
        else:
            _fail("unknown phase");return
    game._disconnect()
    quit(0)
func _fail(message: String) -> void:
    printerr("TASK088 GAME FAIL: "+message);quit(1)
