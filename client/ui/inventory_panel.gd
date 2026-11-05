extends VBoxContainer
class_name EldoriaInventoryPanel

signal item_selected(item_id: String)
signal armor_requested(equip: bool)
signal shield_requested(equip: bool)

const Style = preload("res://ui/ui_style.gd")
const State = preload("res://ui/mock_game_ui_state.gd")
const ItemIcon = preload("res://ui/item_icon.gd")
var state: MockGameUiState
var detail: Label
var armor_equipped := false
var shield_equipped := false

func set_shield_equipped(value: bool) -> void:
	shield_equipped = value
	if is_inside_tree():
		refresh()

func set_armor_equipped(value: bool) -> void:
	armor_equipped = value
	if is_inside_tree():
		refresh()

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	if state != null:
		state.changed.connect(refresh)
	refresh()

func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	if state == null:
		return
	var header := Style.label("РЮКЗАК  ·  Оружие — нажать, чтобы взять · Еда — на игровом экране", 12, Style.MUTED)
	add_child(header)
	var equipment := HBoxContainer.new()
	equipment.name = "EquipmentSlots"
	equipment.add_theme_constant_override("separation", 6)
	add_child(equipment)
	var hand := Button.new()
	hand.name = "MainHandSlot"
	hand.text = "В руках: %s" % str(State.TOOLS.get(state.selected_item,{"name":"Кулаки"})["name"])
	hand.tooltip_text = "Нажмите, чтобы убрать оружие в рюкзак и выбрать кулаки"
	hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand.disabled = state.selected_item == "unarmed"
	Style.button(hand, state.selected_item != "unarmed")
	hand.pressed.connect(func() -> void: item_selected.emit("unarmed"))
	equipment.add_child(hand)
	var chest := Button.new()
	chest.name = "ChestSlot"
	chest.text = "Броня: надета" if armor_equipped else "Броня: —"
	chest.tooltip_text = "Снижает входящий урон на 15% только когда надета"
	chest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chest.disabled = not armor_equipped and state.amount("leather_armor") == 0
	Style.button(chest,armor_equipped)
	chest.pressed.connect(func() -> void: armor_requested.emit(not armor_equipped))
	equipment.add_child(chest)
	var offhand := Button.new()
	offhand.name = "OffhandSlot"
	offhand.text = "Щит: надет" if shield_equipped else "Щит: —"
	offhand.tooltip_text = "Щит во второй руке; лук и копьё требуют две руки"
	offhand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	offhand.disabled = not shield_equipped and state.amount("shield") == 0
	Style.button(offhand,shield_equipped)
	offhand.pressed.connect(func() -> void: shield_requested.emit(not shield_equipped))
	equipment.add_child(offhand)
	var grid := GridContainer.new()
	grid.name = "ItemGrid"
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	add_child(grid)
	var any_item := false
	for item_id in State.ITEMS:
		var data: Dictionary = State.ITEMS[item_id]
		var count: int = state.amount(item_id)
		any_item = any_item or count > 0
		var slot := Button.new()
		slot.name = "ItemSlot_%s" % item_id
		slot.text = "" # The grid shows pictures and quantities, not item names.
		slot.tooltip_text = "%s · %d шт.\n%s" % [data["name"],count,_item_help(item_id)]
		var can_equip: bool = item_id in ["axe","spear","bow","shield","wooden_staff"] and count > 0 and state.can_select_tool(item_id)
		Style.button(slot, state.selected_item == item_id and can_equip)
		slot.custom_minimum_size = Vector2(112, 85)
		slot.focus_mode = Control.FOCUS_NONE
		slot.pressed.connect(_item_pressed.bind(item_id,count,can_equip))
		var icon: Control = ItemIcon.new()
		icon.name = "Icon_%s" % item_id
		icon.setup(item_id,count > 0,state.selected_item == item_id)
		icon.position = Vector2(32,4)
		icon.size = Vector2(48,48)
		slot.add_child(icon)
		var amount_label := Style.label("НАДЕТО" if can_equip and state.selected_item == item_id else "×%d" % count,12 if can_equip and state.selected_item == item_id else 15,Style.GOLD if can_equip and state.selected_item == item_id else Style.TEXT if count > 0 else Style.MUTED)
		amount_label.name = "Quantity"
		amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amount_label.position = Vector2(11,54)
		amount_label.size = Vector2(90,20)
		slot.add_child(amount_label)
		grid.add_child(slot)
	if not any_item:
		add_child(Style.label("Рюкзак пуст. Предметы появятся здесь.", 14, Style.MUTED))
	detail = Style.label("Нажмите на оружие, чтобы экипировать. Броня и щит надеваются через слоты выше.", 13, Style.GOLD)
	detail.name = "ItemDetail"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(detail)

func _item_pressed(item_id: String, count: int, can_equip: bool) -> void:
	if detail != null:
		detail.text = "%s ×%d — %s%s" % [State.ITEMS[item_id]["name"],count,_item_help(item_id),
			" · Экипируется по нажатию" if can_equip else ""]
	if can_equip:
		item_selected.emit(item_id)

func _item_help(item_id: String) -> String:
	if State.RECIPES.has(item_id):
		var description: String = str(State.RECIPES[item_id]["description"])
		if item_id in ["bandage","grilled_meat","mana_potion"]:
			return description + ". Используйте кнопку расходника на игровом экране"
		if item_id == "repair_kit":
			return description + ". Используйте у повреждённого лагеря ночью"
		if item_id == "leather_armor":
			return description + ". Наденьте через слот «Броня» выше"
		if item_id == "shield":
			return description + ". Наденьте через слот «Щит» выше"
		return description
	return "Материал для изготовления предметов у костра" if item_id in ["wood","stone","herb","mana_herb","hide","bone","meat"] else "Предмет из инвентаря"
