extends Node3D
## Visual-only passive animal. Server owns health, movement and respawn.

var species := "rabbit"
var body: Node3D
var last_position := Vector3.ZERO
var life := 1.0
var active := false

func setup(kind: String) -> void:
	species = kind if kind in ["rabbit", "deer", "dummy"] else "rabbit"

func _ready() -> void:
	body = Node3D.new()
	add_child(body)
	var coat := StandardMaterial3D.new()
	coat.albedo_color = Color("b69b7e") if species == "deer" else Color("d0c9b9")
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("655042")
	var nose := StandardMaterial3D.new()
	nose.albedo_color = Color("292729")
	if species == "dummy":
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color("ae8860")
		_box("Post",Vector3(0,0.95,0),Vector3(0.15,1.9,0.15),wood)
		_box("Arms",Vector3(0,1.30,0),Vector3(0.95,0.14,0.14),wood)
		var straw := StandardMaterial3D.new()
		straw.albedo_color = Color("c8b881")
		_sphere("Body",Vector3(0,1.08,0),Vector3(0.35,0.48,0.22),straw)
		_sphere("Head",Vector3(0,1.78,0),Vector3(0.23,0.24,0.23),straw)
		_box("Base",Vector3(0,0.07,0),Vector3(0.8,0.12,0.7),wood)
	elif species == "rabbit":
		_sphere("Body", Vector3(0,0.36,0), Vector3(0.36,0.29,0.48),coat)
		_sphere("Head",Vector3(0,0.56,-0.36),Vector3(0.26,0.24,0.25),coat)
		for side in [-1.0,1.0]:
			_sphere("Ear",Vector3(0.15*side,0.93,-0.38),Vector3(0.095,0.33,0.10),coat)
			_sphere("Eye",Vector3(0.205*side,0.59,-0.51),Vector3(0.04,0.045,0.045),nose)
		_sphere("Tail",Vector3(0,0.46,0.47),Vector3(0.15,0.14,0.15),dark)
	else:
		_sphere("Body",Vector3(0,0.94,0),Vector3(0.45,0.48,0.83),coat)
		_sphere("Head",Vector3(0,1.39,-0.70),Vector3(0.29,0.30,0.35),coat)
		for side in [-1.0,1.0]:
			_sphere("Ear",Vector3(side*0.30,1.62,-0.70),Vector3(0.22,0.10,0.14),coat)
			_sphere("Eye",Vector3(side*0.24,1.46,-0.91),Vector3(0.045,0.045,0.045),nose)
			for z in [-0.49,0.47]:
				_box("Leg",Vector3(side*0.25,0.43,z),Vector3(0.13,0.83,0.14),dark)
		_sphere("Tail",Vector3(0,1.05,0.84),Vector3(0.14,0.19,0.22),dark)
	last_position = position

func _sphere(label: String, point: Vector3, scale_by: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var shape := SphereMesh.new()
	shape.radial_segments = 9
	shape.rings = 5
	mesh.mesh = shape
	mesh.position = point
	mesh.scale = scale_by
	mesh.material_override = mat
	body.add_child(mesh)

func _box(label: String, point: Vector3, size: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = point
	mesh.material_override = mat
	body.add_child(mesh)

func update_state(at: Vector3, hp: int, alive: bool, direction: Vector3) -> void:
	if not active or position.distance_to(at) > 7.0:
		position = at
	else:
		position = position.lerp(at,0.55)
	active = true
	visible = alive
	life = clampf(float(hp)/(24.0 if species == "rabbit" else 100.0 if species == "dummy" else 55.0),0.0,1.0)
	if direction.length_squared() > 0.01:
		rotation.y = atan2(-direction.x,-direction.z)

func _process(_delta: float) -> void:
	if body != null and visible:
		body.position.y = 0.025 * sin(float(Time.get_ticks_msec())*0.009)
