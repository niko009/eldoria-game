extends Node3D
## Visual-only passive animal. Server owns health, movement and respawn.
const RABBIT_MODEL: PackedScene = preload("res://assets/wildlife/Rabbit.glb")
const DEER_MODEL: PackedScene = preload("res://assets/wildlife/Deer.glb")

var species := "rabbit"
var body: Node3D
var animal_mesh: Node3D
var animal_anim: AnimationPlayer
var last_position := Vector3.ZERO
var life := 1.0
var active := false
var stride_clock := 0.0
var speed_visual := 0.0

func setup(kind: String) -> void:
	species = kind if kind in ["rabbit", "deer", "dummy"] else "rabbit"

func _ready() -> void:
	body = Node3D.new()
	add_child(body)
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
	else:
		# Replace abstract primitive shapes with licensed, textured 3D wildlife.
		# Both source GLBs face +Z; game actor forward is -Z.
		animal_mesh = (RABBIT_MODEL if species == "rabbit" else DEER_MODEL).instantiate()
		animal_mesh.name = "WildlifeModel"
		animal_mesh.rotation.y = PI
		if species == "rabbit":
			# Source bounding box -0.9..0.9 Y. A real rabbit is not 1.8 m tall.
			animal_mesh.scale = Vector3.ONE * 0.46
			animal_mesh.position.y = 0.41
		else:
			# Imported stag is 1.69 m tall and grounded at Y=0.
			animal_mesh.scale = Vector3.ONE * 1.0
			animal_anim = animal_mesh.get_node_or_null("AnimationPlayer")
			if animal_anim != null and animal_anim.has_animation("Idle"):
				animal_anim.play("Idle")
		body.add_child(animal_mesh)
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
	var travelled := position.distance_to(at)
	if not active or position.distance_to(at) > 7.0:
		position = at
	else:
		position = position.lerp(at,0.55)
	active = true
	visible = alive
	life = clampf(float(hp)/(24.0 if species == "rabbit" else 100.0 if species == "dummy" else 55.0),0.0,1.0)
	if direction.length_squared() > 0.01:
		rotation.y = atan2(-direction.x,-direction.z)
	# Server sends velocity direction only while walking/fleeing. Keep animation
	# decoupled from network frame cadence and don't animate dead creatures.
	if species != "dummy":
		speed_visual = minf(1.0,travelled * 5.0) if direction.length_squared() > 0.01 else 0.0
	last_position = at

func _process(delta: float) -> void:
	if body != null and visible:
		if species == "dummy":
			return
		stride_clock += delta * lerpf(2.2,10.0,speed_visual)
		if species == "rabbit":
			# Short hops with a planted phase, not a flying/hovering ball.
			var hop := pow(maxf(0.0,sin(stride_clock)),2.0)
			body.position.y = hop * 0.22 * speed_visual
			body.rotation.x = -0.09 * speed_visual * cos(stride_clock)
		else:
			body.position.y = sin(stride_clock*1.65) * 0.028 * speed_visual
			body.rotation.z = sin(stride_clock) * 0.026 * speed_visual
