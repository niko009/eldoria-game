extends Control
## Crisp vector equipment silhouettes; no external image assets or fonts needed.
## TASK-025B: icons render at native resolution and scale on Android/desktop.

var tool_id := "unarmed"
var available := true
var active := false

func configure(kind: String, unlocked: bool, highlighted: bool) -> void:
	tool_id = kind
	available = unlocked
	active = highlighted
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(46, 46)

func _draw() -> void:
	var steel := Color("f8deb0") if active else Color("cbd6d2")
	var edge := Color("ffe7b2") if active else Color("e2e9e5")
	var wood := Color("aa744b") if active else Color("81684d")
	var dark := Color("53636b")
	if not available:
		steel = Color("697478")
		edge = Color("849095")
		wood = Color("655f5a")
		dark = Color("4a5155")
	draw_set_transform((size - Vector2(48, 48)) * 0.5)
	match tool_id:
		"unarmed":
			_fist(steel, edge, dark)
		"sword":
			_sword(steel, edge, wood)
		"pickaxe":
			_pickaxe(steel, edge, wood)
		"axe":
			_axe(steel, edge, wood)
		"hammer":
			_hammer(steel, edge, wood)
		"bow":
			_bow(steel, edge, wood)
		"spear":
			_spear(steel, edge, wood)
		"wooden_staff":
			_stroke(Vector2(13,43),Vector2(32,9),wood,5)
			draw_circle(Vector2(33,9),7,Color("83ccf2") if available else dark)
		"shield":
			_shield(steel, edge, wood)

func _spear(steel: Color, edge: Color, wood: Color) -> void:
	_stroke(Vector2(12,43),Vector2(35,11),wood,4)
	_poly([Vector2(35,3),Vector2(41,14),Vector2(33,21),Vector2(28,13)],steel)
	_stroke(Vector2(35,5),Vector2(33,17),edge,1.5)

func _shield(steel: Color, edge: Color, wood: Color) -> void:
	_poly([Vector2(24,5),Vector2(40,12),Vector2(38,31),Vector2(24,43),Vector2(10,31),Vector2(8,12)],steel)
	_poly([Vector2(24,10),Vector2(34,15),Vector2(33,29),Vector2(24,36),Vector2(15,29),Vector2(14,15)],wood)
	_stroke(Vector2(24,10),Vector2(24,36),edge,2)
	draw_circle(Vector2(24,22),4,edge)

func _poly(points: Array[Vector2], color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func _stroke(a: Vector2, b: Vector2, color: Color, width: float = 3.0) -> void:
	draw_line(a, b, color, width, true)

func _fist(steel: Color, edge: Color, dark: Color) -> void:
	_poly([Vector2(14,22), Vector2(12,17), Vector2(15,13), Vector2(20,14), Vector2(22,12), Vector2(27,14), Vector2(29,12), Vector2(34,14), Vector2(35,22), Vector2(31,27), Vector2(31,36), Vector2(18,37), Vector2(15,29)], steel)
	for x in [18.0, 24.0, 30.0]:
		_stroke(Vector2(x,16), Vector2(x,22), dark, 1.4)
	_stroke(Vector2(17,30), Vector2(30,30), edge, 1.5)

func _sword(steel: Color, edge: Color, wood: Color) -> void:
	_poly([Vector2(12,37), Vector2(15,40), Vector2(27,28), Vector2(25,26)], wood)
	_poly([Vector2(25,27), Vector2(21,23), Vector2(35,7), Vector2(40,5), Vector2(39,11), Vector2(28,29)], steel)
	_stroke(Vector2(26,26), Vector2(37,9), edge, 1.5)
	_stroke(Vector2(17,25), Vector2(29,37), wood, 4)
	draw_circle(Vector2(12,40), 3, edge)

func _axe(steel: Color, edge: Color, wood: Color) -> void:
	_stroke(Vector2(15,40), Vector2(31,9), wood, 5.5)
	_stroke(Vector2(16,39), Vector2(30,12), Color("e6b47f") if active else Color("a98865"), 1.8)
	_poly([Vector2(27,9), Vector2(37,11), Vector2(43,6), Vector2(40,17), Vector2(42,25), Vector2(32,21), Vector2(25,17)], steel)
	_poly([Vector2(37,11), Vector2(43,6), Vector2(40,17), Vector2(42,25), Vector2(36,22)], edge)

func _pickaxe(steel: Color, edge: Color, wood: Color) -> void:
	_stroke(Vector2(23,41), Vector2(25,13), wood, 5)
	_poly([Vector2(5,17), Vector2(10,12), Vector2(21,9), Vector2(28,10), Vector2(39,14), Vector2(43,20), Vector2(32,17), Vector2(25,16), Vector2(18,16)], steel)
	_stroke(Vector2(7,17), Vector2(24,12), edge, 1.8)

func _hammer(steel: Color, edge: Color, wood: Color) -> void:
	_stroke(Vector2(17,40), Vector2(29,15), wood, 6)
	_poly([Vector2(16,8), Vector2(35,16), Vector2(30,25), Vector2(11,17)], steel)
	_stroke(Vector2(15,10), Vector2(32,17), edge, 2)

func _bow(steel: Color, edge: Color, wood: Color) -> void:
	draw_polyline(PackedVector2Array([Vector2(31,5), Vector2(20,10), Vector2(15,20), Vector2(17,30), Vector2(31,42)]), wood, 4, true)
	_stroke(Vector2(31,5), Vector2(31,42), edge, 1.5)
	_stroke(Vector2(9,23), Vector2(39,23), steel, 2)
	_poly([Vector2(37,20), Vector2(43,23), Vector2(37,26)], steel)
