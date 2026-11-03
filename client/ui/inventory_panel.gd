extends VBoxContainer
class_name EldoriaInventoryPanel

signal item_selected(item_id: String)

const Style = preload("res://ui/ui_style.gd")
const State = preload("res://ui/mock_game_ui_state.gd")
const ItemIcon = preload("res://ui/item_icon.gd")
var state: MockGameUiState
var detail: Label

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
	var header := Style.label("РЮКЗАК  ·  Нажмите на иконку", 13, Style.MUTED)
	add_child(header)
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
		slot.tooltip_text = "%s · %d шт." % [data["name"],count]
		var can_equip: bool = item_id in ["axe","spear","bow","shield"] and count > 0
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
		var amount_label := Style.label("×%d" % count,15,Style.TEXT if count > 0 else Style.MUTED)
		amount_label.name = "Quantity"
		amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amount_label.position = Vector2(11,54)
		amount_label.size = Vector2(90,20)
		slot.add_child(amount_label)
		grid.add_child(slot)
	if not any_item:
		add_child(Style.label("Рюкзак пуст. Предметы появятся здесь.", 14, Style.MUTED))
	detail = Style.label("В руках: %s" % State.TOOLS.get(state.selected_item,{"name":state.selected_item})["name"], 14, Style.GOLD)
	detail.name = "ItemDetail"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(detail)

func _item_pressed(item_id: String, count: int, can_equip: bool) -> void:
	if detail != null:
		detail.text = "%s  ×%d%s" % [State.ITEMS[item_id]["name"],count,
			" · экипировать" if can_equip else ""]
	if can_equip:
		item_selected.emit(item_id)
