extends Node3D
## Lightweight stylized stone axe. Mesh-only prop — no physics or gameplay authority.
## Fits KayKit's built-in right-hand BoneAttachment3D (handslot_r).
class_name EldoriaStoneAxe

const WOOD := Color("775031")
const WOOD_HIGHLIGHT := Color("b98a54")
const STONE := Color("85999c")
const STONE_EDGE := Color("cfdbd0")
const ROPE := Color("d2b57a")
const METAL := Color("697e7d")

func _ready() -> void:
	name = "EquippedStoneAxe"
	_construct()

func _construct() -> void:
	# The bone's +Y axis is the length of the weapon; Godot CylinderMesh is Y-up.
	_cylinder("OakHandle", 0.041, 0.051, 0.78, WOOD, Vector3(0, 0.14, 0), 8)
	_cylinder("HandleCore", 0.024, 0.024, 0.64, WOOD_HIGHLIGHT, Vector3(0, 0.17, 0), 8)
	# Stone blade points to the side, not through the hand, and has a readable,
	# slightly chipped edge. Four quads per side, no alpha or expensive shader.
	_blade()
	# Durable cord wrapped around the head to make this a stone-age tool.
	for y in [0.36, 0.405, 0.45]:
		_cylinder("Binding", 0.075, 0.075, 0.016, ROPE, Vector3(0.03, y, 0), 8)
	_cylinder("Pommel", 0.055, 0.051, 0.042, METAL, Vector3(0, -0.24, 0), 8)

func _cylinder(label: String, bottom: float, top: float, height: float,
		color: Color, at: Vector3, sides: int) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.mesh = mesh
	instance.position = at
	instance.material_override = _material(color)
	add_child(instance)

func _blade() -> void:
	# Sharp side: outline in xy plane.  Thickness tapers toward the outer tip.
	var outline: Array[Vector2] = [
		Vector2(-0.095, 0.32),
		Vector2(0.14, 0.295),
		Vector2(0.46, 0.16),
		Vector2(0.58, 0.20),
		Vector2(0.55, 0.50),
		Vector2(0.43, 0.60),
		Vector2(0.13, 0.465),
		Vector2(-0.095, 0.46)
	]
	var middle := Vector3(0.18, 0.389, 0)
	var mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for idx in range(outline.size()):
		var next := (idx + 1) % outline.size()
		var p: Vector2 = outline[idx]
		var q: Vector2 = outline[next]
		var dz_p := 0.012 if p.x > 0.44 else 0.070
		var dz_q := 0.012 if q.x > 0.44 else 0.070
		for side in [-1.0, 1.0]:
			var a := Vector3(p.x, p.y, dz_p * side)
			var b := Vector3(q.x, q.y, dz_q * side)
			if side < 0:
				_triangle(surface, middle + Vector3(0, 0, -0.085), b, a, STONE)
			else:
				_triangle(surface, middle + Vector3(0, 0, 0.085), a, b, STONE_EDGE if p.x > 0.43 else STONE)
			_triangle(surface, a, b, Vector3(q.x, q.y, -dz_q * side),
				STONE.darkened(0.18))
	surface.generate_normals()
	surface.set_material(_material(Color.WHITE, true))
	surface.commit(mesh)
	var head := MeshInstance3D.new()
	head.name = "CarvedStoneBlade"
	head.mesh = mesh
	add_child(head)

func _triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	for p in [a, b, c]:
		tool.set_color(color)
		tool.add_vertex(p)

func _material(color: Color, vertex_color: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.vertex_color_use_as_albedo = vertex_color
	mat.roughness = 0.86
	mat.metallic = 0.08
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
