extends SceneTree
# Two separate game clients exercise actual WS craft RPC and UI snapshots.
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var a := OS.get_cmdline_user_args().has("--a")
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    if a:
        game.selected_avatar = 2 # distinguish crafter from second client
    else:
        game.selected_avatar = 0
    game._join_websocket("ws://127.0.0.1:7788")
    for i in range(540):
        await process_frame
        if game.own_id > 0 and game.players.size() == 2 and game.placed_buildings.has(777):
            break
    if game.own_id == 0 or game.players.size() != 2 or not game.placed_buildings.has(777):
        _fail("missing actual connected world state")
        return
    if game.live_ui == null:
        _fail("new live UI wasn't initialized")
        return
    # Building RPC may arrive just after _process() for this frame.
    for frame in range(35):
        await process_frame
    if a:
        for i in range(320):
            await process_frame
            if int(game.player_inventories.get(game.own_id, {}).get("wood", 0)) == 4:
                break
        if game.player_inventories[game.own_id].get("wood", 0) != 4:
            _fail("crafter inventory not received")
            return
        if not game.live_ui.state.near_campfire:
            _fail("client didn't detect replicated crafting station at " + str(game.players[game.own_id].position) + " buildings=" + str(game.placed_buildings))
            return
        game._try_craft_axe()
        for i in range(450):
            await process_frame
            if game.player_inventories[game.own_id].get("axe", 0) == 1:
                break
        if game.player_inventories[game.own_id] != {"wood": 2, "stone": 2, "herb": 0, "axe": 1}:
            _fail("craft snapshot incorrect")
            return
        if game.live_ui.state.amount("axe") != 1:
            _fail("UI didn't reflect server-authoritative crafted axe")
            return
        game.live_ui.state.select_item("axe")
        for i in range(150):
            await process_frame
            if game.live_ui.state.equipped_axe:
                break
        if not game.live_ui.state.equipped_axe:
            _fail("authoritative equipment ACK not received")
            return
        game.live_ui.state.select_item("wood")
        for i in range(150):
            await process_frame
            if not game.live_ui.state.equipped_axe:
                break
        if game.live_ui.state.equipped_axe:
            _fail("unequip ACK missing")
            return
        game.live_ui.state.select_item("axe")
        game.request_craft_axe.rpc_id(1)
        for i in range(120):
            await process_frame
        if game.player_inventories[game.own_id].get("wood", -1) != 2:
            _fail("repeated request debited materials")
            return
        # Keep the connected peer visible until the authoritative host verifies
        # all final inventories and the independent observer receives feedback.
        for i in range(310):
            await process_frame
    else:
        game.request_equip_axe.rpc_id(1, true) # cannot equip an axe not owned
        game.request_craft_axe.rpc_id(1) # no resources
        for i in range(320):
            await process_frame
            if game.info.text.contains("Need 2 wood"):
                break
        if not game.info.text.contains("Need 2 wood") or game.player_inventories[game.own_id].get("axe", 0) != 0:
            _fail("unfunded remote request wasn't rejected: " + game.info.text + " at " + str(game.players[game.own_id].position))
            return
        if game.live_ui.state.equipped_axe:
            _fail("nonowner was allowed to equip")
            return
        # Keep observer present until the host compares both player inventories.
        for i in range(550):
            await process_frame
    print("CRAFT NETWORK CLIENT PASS " + ("A" if a else "B"))
    game._disconnect()
    quit(0)
func _fail(reason: String) -> void:
    printerr("CRAFT NETWORK CLIENT FAIL " + reason)
    quit(1)
