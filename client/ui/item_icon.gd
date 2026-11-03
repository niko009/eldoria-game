extends Control
## Lightweight vector illustrations shared by inventory and crafting.
## All shapes use Godot draw primitives; no fonts, SVG imports or remote assets.
const EquipmentIcon = preload("res://ui/tool_icon.gd")
var item_id := "wood"
var enabled := true
var highlighted := false

func setup(id: String, is_enabled: bool = true, selected: bool = false) -> void:
	item_id = id
	enabled = is_enabled
	highlighted = selected
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(48,48)
	if item_id in ["axe","spear","bow","shield"]:
		# Equipment has recognizable silhouettes already; share the same art.
		var equipment := EquipmentIcon.new()
		equipment.name = "EquipmentSymbol"
		equipment.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(equipment)
		equipment.configure(item_id,enabled,highlighted)

func _draw() -> void:
	if item_id in ["axe","spear","bow","shield"]:
		return
	var c := Color("dfc78f") if enabled else Color("727c7d")
	var green := Color("9cc78b") if enabled else Color("717d75")
	var iron := Color("bdcdd0") if enabled else Color("657378")
	var center := size*0.5
	draw_set_transform(center-Vector2(24,24))
	match item_id:
		"wood":
			for shift in [0.0,10.0,20.0]:
				var x: float = 7.0+shift
				draw_line(Vector2(x,39),Vector2(x+8,11),Color("946846") if enabled else c,8,true)
				draw_line(Vector2(x+1,35),Vector2(x+7,14),c,2,true)
			draw_line(Vector2(7,39),Vector2(35,39),Color("745037"),3)
		"stone":
			_shape([Vector2(7,31),Vector2(14,13),Vector2(32,10),Vector2(42,26),Vector2(34,40),Vector2(15,39)],iron)
			_shape([Vector2(14,13),Vector2(32,10),Vector2(26,29),Vector2(7,31)],Color("e3e8e1") if enabled else c)
			_shape([Vector2(26,29),Vector2(42,26),Vector2(34,40),Vector2(15,39)],Color("8fa6aa") if enabled else c)
		"herb":
			draw_line(Vector2(24,42),Vector2(24,9),green,3,true)
			for px in [11.0,26.0]:
				_shape([Vector2(24,35),Vector2(px,28),Vector2(px-3,14),Vector2(24,22)],green)
			_shape([Vector2(24,24),Vector2(28,9),Vector2(35,5),Vector2(32,20)],Color("b9d99a") if enabled else c)
		"bandage":
			draw_rect(Rect2(10,9,29,30),Color("eee4ce") if enabled else c,true)
			draw_rect(Rect2(10,9,29,30),Color("8a8a81"),false,2)
			draw_rect(Rect2(21,13,7,23),Color("bf6763") if enabled else c,true)
			draw_rect(Rect2(13,21,23,7),Color("bf6763") if enabled else c,true)
		"repair_kit":
			draw_rect(Rect2(8,16,33,25),Color("ae784c") if enabled else c,true)
			draw_rect(Rect2(8,16,33,25),Color("e7bd7e") if enabled else c,false,3)
			draw_arc(Vector2(24.5,16),9,PI,TAU,12,iron,4,true)
			draw_line(Vector2(24,21),Vector2(24,34),iron,3)
			draw_line(Vector2(17,28),Vector2(31,28),iron,3)
		"arrow":
			draw_line(Vector2(9,38),Vector2(38,8),Color("b68a5e") if enabled else c,4,true)
			_shape([Vector2(30,8),Vector2(44,3),Vector2(40,17)],iron)
			_shape([Vector2(10,36),Vector2(8,26),Vector2(18,31)],green)
			_shape([Vector2(11,35),Vector2(20,38),Vector2(15,28)],green)
		_:
			draw_circle(Vector2(24,24),14,c)

func _shape(points: Array[Vector2], color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points),color)