extends RefCounted
class_name EldoriaUiStyle

const GOLD := Color("e8bd70")
const TEXT := Color("f3efdf")
const MUTED := Color("c4beb0")
const DARK := Color("172026", 0.94)

static func panel(color: Color = DARK, border: Color = Color("9c8059"), radius: int = 16) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.shadow_color = Color(0, 0, 0, 0.18)
	box.shadow_size = 3
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 10
	box.content_margin_bottom = 10
	return box

static func button(button_node: Button, selected: bool = false) -> void:
	button_node.custom_minimum_size = Vector2(48, 48)
	button_node.add_theme_color_override("font_color", TEXT)
	button_node.add_theme_color_override("font_disabled_color", MUTED)
	button_node.add_theme_color_override("font_hover_color", Color.WHITE)
	button_node.add_theme_stylebox_override("normal", panel(Color("202a30", 0.91), GOLD if selected else Color("5f655f"), 12))
	button_node.add_theme_stylebox_override("hover", panel(Color("3a4547"), GOLD, 12))
	button_node.add_theme_stylebox_override("pressed", panel(Color("584b37"), GOLD, 12))
	button_node.add_theme_stylebox_override("disabled", panel(Color("20282b", 0.7), Color("454b4b"), 12))

static func label(value: String, size: int = 16, color: Color = TEXT) -> Label:
	var node := Label.new()
	node.text = value
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	return node
