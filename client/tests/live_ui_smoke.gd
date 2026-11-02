extends SceneTree

# TASK-021B: offline integration smoke. No live network/server required.
func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene: PackedScene = load("res://Main.tscn")
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    if game.live_ui == null:
        push_error("LIVE UI missing from actual Main scene")
        quit(1)
        return
    var ui = game.live_ui
    if ui.state.amount("wood") != 0:
        push_error("Live UI must not show fake inventory")
        quit(2)
        return
    game.inventory_snapshot({"wood": 6, "stone": 5, "herb": 3}) # no connected player: ignored by design
    ui.set_inventory({"wood": 6, "stone": 5, "herb": 3})
    if ui.state.amount("wood") != 6:
        push_error("UI inventory adapter failed")
        quit(3)
        return
    if ui.hud.resource_counts["wood"].text != "6" or ui.hud.resource_counts["stone"].text != "5" or ui.hud.resource_counts["herb"].text != "3":
        push_error("Top resource counters are not updated from live inventory")
        quit(13)
        return
    if EldoriaHotbar.SLOTS != ["unarmed", "sword", "pickaxe", "axe", "hammer", "bow"]:
        push_error("Tool-only hotbar layout or axe slot 4 incorrect")
        quit(14)
        return
    for tool_id in EldoriaHotbar.SLOTS:
        var slot: Button = ui.hud.hotbar.slot_buttons[tool_id]
        if not slot.text.is_empty():
            push_error("Tool slot must not show resource quantities or text")
            quit(15)
            return
        if tool_id != "unarmed" and not slot.disabled:
            push_error("Unowned or unavailable equipment should be disabled")
            quit(16)
            return
    ui._open("build")
    if ui.active_panel != "build" or not ui.overlay.visible:
        push_error("Building modal failed")
        quit(4)
        return
    ui._close()
    ui._open("craft")
    if not ui.current_panel is EldoriaCraftingPanel or not ui.current_panel.craft_enabled:
        push_error("Stone axe crafting panel missing")
        quit(5)
        return
    if ui.state.near_campfire:
        push_error("Live client must not claim a fictitious crafting station")
        quit(7)
        return
    ui.set_near_campfire(true)
    var requested := [0]
    ui.craft_requested.connect(func() -> void: requested[0] += 1)
    ui._craft("axe")
    if requested[0] != 1 or ui.active_panel != "":
        push_error("Live crafting request did not dispatch to game exactly once")
        quit(8)
        return
    ui.set_inventory({"wood": 4, "stone": 3, "axe": 1})
    if ui.hud.hotbar.slot_buttons["axe"].disabled:
        push_error("Crafted axe slot should become selectable")
        quit(17)
        return
    var equips: Array[bool] = []
    ui.equip_requested.connect(func(equip: bool) -> void: equips.append(equip))
    ui.state.select_item("axe")
    if equips.is_empty() or not equips[-1]:
        push_error("Axe slot did not request equipment")
        quit(10)
        return
    ui.set_equipped_axe(true)
    if not ui.state.equipped_axe:
        push_error("Equipment ACK didn't update UI")
        quit(11)
        return
    ui.state.select_item("wood")
    if equips[-1] or ui.state.selected_item != "unarmed":
        push_error("Hotbar didn't request unequip")
        quit(12)
        return
    ui.set_equipped_axe(false)
    ui._craft("axe")
    if requested[0] != 1:
        push_error("Duplicate stone axe request allowed by client")
        quit(9)
        return
    ui._close()
    var output := Vector2.ZERO
    ui.joystick_moved.connect(func(direction: Vector2) -> void: output = direction)
    ui.hud.joystick._set_direction(Vector2(104, 54))
    ui._on_action("gather")
    ui._on_action("jump")
    ui._open("settings")
    if ui.active_panel != "settings":
        push_error("Settings modal missing")
        quit(6)
        return
    print("TASK021B LIVE UI SMOKE PASS")
    quit(0)
