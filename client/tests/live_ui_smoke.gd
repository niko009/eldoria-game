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
    ui.set_inventory({"wooden_staff":1})
    ui.set_avatar(2)
    ui.state.select_item("wooden_staff")
    ui._open("inventory")
    var main_hand: Button = ui.current_panel.get_node("EquipmentSlots/MainHandSlot")
    if not main_hand.text.contains("Посох") or main_hand.disabled:
        push_error("Inventory must show equipped staff and allow unequip")
        quit(35)
        return
    var staff_slot: Button = ui.current_panel.get_node("ItemGrid/ItemSlot_wooden_staff")
    if staff_slot.get_node("Quantity").text != "НАДЕТО":
        push_error("Equipped staff should be visually marked")
        quit(36)
        return
    ui.current_panel.get_node("InventoryCategories/Filter_Ресурсы").pressed.emit()
    if ui.current_panel.get_node_or_null("ItemGrid/ItemSlot_wooden_staff") != null:
        push_error("Resource filter shows equipped weapon")
        quit(37)
        return
    ui.current_panel.get_node("InventoryCategories/Filter_Оружие").pressed.emit()
    if ui.current_panel.get_node_or_null("ItemGrid/ItemSlot_wooden_staff") == null:
        push_error("Weapon filter hides owned staff")
        quit(38)
        return
    ui.current_panel.get_node("InventoryCategories/Filter_Расходники").pressed.emit()
    if ui.current_panel.get_node_or_null("ItemGrid/ItemSlot_wooden_staff") != null:
        push_error("Consumables filter shows staff")
        quit(39)
        return
    ui.current_panel.get_node("InventoryCategories/Filter_Все").pressed.emit()
    if ui.current_panel.get_node_or_null("ItemGrid/ItemSlot_wooden_staff") == null:
        push_error("All-items filter does not restore owned staff")
        quit(40)
        return
    ui._close()
    ui.state.select_item("unarmed")
    ui.set_inventory({"wooden_staff":1})
    ui.set_avatar(2)
    var selection: Array[String] = []
    ui.combat_equip_requested.connect(func(item: String) -> void: selection.append(item))
    ui.state.select_item("wooden_staff")
    if selection.is_empty() or selection.back() != "wooden_staff" or ui.state.selected_item != "wooden_staff":
        push_error("Staff icon does not request equipping a crafted staff")
        quit(33)
        return
    if ui.hud.hotbar.slot_buttons["wooden_staff"].disabled:
        push_error("Owned staff must be available in hotbar")
        quit(34)
        return
    ui.state.select_item("unarmed")
    ui.set_inventory({})
    ui.set_combat_equipment("bow")
    if ui.hud.action_controls["attack"].get_node("Caption").text != "ВЫСТРЕЛ":
        push_error("Bow attack caption was overwritten")
        quit(24)
        return
    ui.set_combat_equipment("spear")
    if ui.hud.action_controls["attack"].get_node("Caption").text != "УКОЛ":
        push_error("Spear attack caption was overwritten")
        quit(25)
        return
    ui.set_combat_equipment("unarmed")
    ui.set_avatar(2)
    ui.set_hero_class(2)
    if ui.hud.action_controls["attack"].get_node("Caption").text != "МАГИЯ":
        push_error("Mage attack caption was overwritten")
        quit(26)
        return
    if not ui.combat_aim_help.text.contains("МАГИЯ"):
        push_error("Mage aim hint incorrectly describes spear combat")
        quit(27)
        return
    ui.set_combat_equipment("wooden_staff")
    if not ui.hud.selected_tool_hint.text.contains("ПОСОХ"):
        push_error("Equipped wooden staff is not described by HUD")
        quit(28)
        return
    ui.set_combat_target_status("no_ammo")
    if ui.combat_aim_help.text.contains("НЕТ СТРЕЛ"):
        push_error("Bow ammo warning leaked into mage HUD")
        quit(29)
        return
    ui.set_combat_target_status("none")
    ui.set_combat_target_status("blocked")
    ui.set_combat_equipment("spear")
    if ui.combat_target_status != "none" or ui.combat_aim_help.text.contains("ПРЕПЯТСТВИЕ"):
        push_error("Old target lock hint survived weapon switch")
        quit(30)
        return
    ui.set_combat_equipment("bow")
    if ui.combat_target_status != "no_ammo":
        push_error("Bow without arrows should report unavailable ammo")
        quit(31)
        return
    ui.set_combat_equipment("wooden_staff")
    if ui.combat_target_status != "none" or ui.combat_aim_help.text.contains("СТРЕЛ"):
        push_error("Bow ammo warning survived mage staff switch")
        quit(32)
        return
    ui.set_combat_equipment("unarmed")
    ui.set_avatar(0)
    ui.set_hero_class(0)
    if ui.hud.quick_consumables.visible:
        push_error("Empty quick consumables must not obscure the game view")
        quit(22)
        return
    ui.set_inventory({"bandage":2,"repair_kit":1,"mana_potion":1})
    if not ui.hud.quick_buttons["bandage"].visible or ui.hud.quick_buttons["repair_kit"].visible or ui.hud.quick_buttons["mana_potion"].visible:
        push_error("HUD consumables should respect context and class")
        quit(23)
        return
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
    if not ui.hud.craft_badge.visible or ui.hud.craft_badge_label.text != str(ui.state.ready_recipe_count()):
        push_error("Crafting badge did not react to live inventory")
        quit(18)
        return
    ui.set_inventory({"wood": 6, "stone": 5, "herb": 3, "leather_armor": 1})
    ui._open("inventory")
    var chest: Button = ui.current_panel.get_node("EquipmentSlots/ChestSlot")
    if chest.disabled or not chest.text.contains("—"):
        push_error("Owned armor must be equippable but not worn automatically")
        quit(19)
        return
    ui.set_armor_equipped(true)
    chest = ui.current_panel.get_node("EquipmentSlots/ChestSlot")
    if not chest.text.contains("надета"):
        push_error("Armor snapshot did not update inventory slot")
        quit(20)
        return
    ui.set_inventory({"wood":6,"stone":5,"shield":1,"leather_armor":1})
    ui.set_shield_equipped(true)
    var offhand: Button = ui.current_panel.get_node("EquipmentSlots/OffhandSlot")
    if not offhand.text.contains("надет"):
        push_error("Server offhand state not reflected in inventory")
        quit(21)
        return
    ui._close()
    ui.set_inventory({"wood":6,"stone":5,"herb":3})
    if EldoriaHotbar.SLOTS != ["unarmed", "spear", "shield", "axe", "bow", "wooden_staff", "hammer"]:
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
    ui.craft_requested.connect(func(recipe_id: String) -> void:
        if recipe_id == "axe":
            requested[0] += 1)
    ui._craft("axe")
    if requested[0] != 1 or ui.active_panel != "craft":
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
    ui.set_inventory({"wood": 4, "stone": 3, "axe": 1, "spear": 1, "bow": 1, "shield": 1, "arrow": 5})
    for weapon in ["spear","bow","shield"]:
        if ui.hud.hotbar.slot_buttons[weapon].disabled:
            push_error("Owned weapon unavailable on hotbar: "+weapon)
            quit(19)
            return
    var combat_requests: Array[String] = []
    ui.combat_equip_requested.connect(func(weapon: String) -> void: combat_requests.append(weapon))
    ui.state.select_item("spear")
    ui.set_combat_equipment("spear")
    ui.state.select_item("bow")
    ui.set_combat_equipment("bow")
    ui.state.select_item("shield")
    ui.set_combat_equipment("shield")
    if combat_requests.slice(-3) != ["spear","bow","shield"] or ui.state.selected_item != "shield":
        push_error("Hotbar did not route owned combat weapons to server equipment")
        quit(20)
        return
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
