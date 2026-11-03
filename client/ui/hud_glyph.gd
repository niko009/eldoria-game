extends Control
## Resolution-independent vector glyphs for the Eldoria adventure HUD.
## No emoji fonts, bitmap atlases, shaders or extra mobile draw calls.
class_name EldoriaHudGlyph

var kind := "bag"
var accent := Color("d7bd85")

func setup(name: String, color: Color = Color("d7bd85")) -> void:
	kind = name
	accent = color
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var k := size.x / 48.0
	draw_set_transform(Vector2.ZERO, 0, Vector2(k, k))
	var pale := Color("f5e8c7")
	var muted := Color("acb9ae")
	match kind:
		"bag":
			_poly([Vector2(12,19), Vector2(36,19), Vector2(40,39), Vector2(8,39)], accent)
			draw_arc(Vector2(24,19), 9, PI, TAU, 18, pale, 3)
			_line(Vector2(17,29), Vector2(31,29), pale, 2)
		"build":
			_line(Vector2(14,39), Vector2(14,19), muted, 4)
			_line(Vector2(34,39), Vector2(34,19), muted, 4)
			_poly([Vector2(5,23), Vector2(24,8), Vector2(43,23)], accent)
			_line(Vector2(12,31), Vector2(36,31), pale, 2)
		"craft":
			_line(Vector2(13,39), Vector2(32,12), muted, 5)
			_poly([Vector2(23,8), Vector2(38,16), Vector2(32,27), Vector2(17,19)], accent)
			draw_circle(Vector2(13,39), 3, pale)
		"settings":
			for i in 8:
				var a := TAU * float(i) / 8
				var vec := Vector2(cos(a), sin(a))
				_line(Vector2(24,24) + vec * 12, Vector2(24,24) + vec * 19, accent, 5)
			draw_arc(Vector2(24,24), 13, 0, TAU, 32, accent, 5)
			draw_circle(Vector2(24,24), 5, pale)
		"attack":
			_poly([Vector2(10,38), Vector2(14,42), Vector2(29,27), Vector2(25,23)], muted)
			_poly([Vector2(25,25), Vector2(19,19), Vector2(36,6), Vector2(42,5), Vector2(40,12), Vector2(30,29)], pale)
			_line(Vector2(19,27), Vector2(29,37), accent, 4)
		"gather":
			_poly([Vector2(24,11), Vector2(16,17), Vector2(13,27), Vector2(20,38), Vector2(29,40), Vector2(36,29), Vector2(32,17)], accent)
			_line(Vector2(24,11), Vector2(24,26), pale, 3)
			_line(Vector2(16,20), Vector2(21,28), pale, 2)
		"jump":
			_poly([Vector2(24,7), Vector2(7,27), Vector2(18,27), Vector2(18,40), Vector2(30,40), Vector2(30,27), Vector2(41,27)], accent)
			_line(Vector2(24,18), Vector2(24,33), pale, 2.5)
		"sprint":
			_line(Vector2(6,24), Vector2(19,24), muted, 3)
			_line(Vector2(4,32), Vector2(14,32), muted, 3)
			_poly([Vector2(21,12), Vector2(36,17), Vector2(40,29), Vector2(35,40), Vector2(20,35), Vector2(13,40), Vector2(10,35), Vector2(24,25)], accent)
			_line(Vector2(22,21), Vector2(33,28), pale, 2)
		"wood":
			_poly([Vector2(12,13), Vector2(33,8), Vector2(39,17), Vector2(34,35), Vector2(13,40), Vector2(9,31)], accent)
			_line(Vector2(15,14), Vector2(16,36), pale, 2)
			_line(Vector2(23,12), Vector2(25,36), pale, 2)
		"stone":
			_poly([Vector2(11,32), Vector2(16,17), Vector2(30,11), Vector2(39,21), Vector2(35,37), Vector2(18,39)], accent)
			_poly([Vector2(16,17), Vector2(30,11), Vector2(28,27), Vector2(18,39), Vector2(11,32)], pale.darkened(0.25))
			_line(Vector2(28,27), Vector2(35,37), pale, 2)
		"herb":
			_line(Vector2(24,41), Vector2(24,12), pale, 3)
			_poly([Vector2(24,24), Vector2(11,20), Vector2(7,9), Vector2(19,12)], accent)
			_poly([Vector2(24,32), Vector2(37,28), Vector2(41,15), Vector2(28,18)], accent.lightened(0.13))
			_poly([Vector2(23,18), Vector2(21,9), Vector2(27,5), Vector2(31,11)], pale)

func _line(from: Vector2, to: Vector2, color: Color, thickness: float) -> void:
	draw_line(from, to, color, thickness, true)

func _poly(points: Array[Vector2], color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)
