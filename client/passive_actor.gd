extends Node3D
## Visual-only passive animal. Server owns health, movement and respawn.
const RABBIT_MODEL: PackedScene = preload("res://assets/wildlife/Rabbit.glb")
const DEER_MODEL: PackedScene = preload("res://assets/wildlife/Deer.glb")
var presentation := preload("res://visual_fx/creature_motion.gd").new()
var was_alive := false

var species := "rabbit"
var body: Node3D
var animal_mesh: Node3D
var animal_anim: AnimationPlayer
var last_position := Vector3.ZERO
var life := 1.0
var active := false
var stride_clock := 0.0
var speed_visual := 0.0
var target_yaw := 0.0
var deer_skeleton: Skeleton3D
var deer_legs: Array[int] = []
var deer_shins: Array[int] = []
var deer_gait := 0.0
var deer_motion := 0.0
var health_track: MeshInstance3D
var health_fill: MeshInstance3D

func setup(kind: String) -> void:
	species = kind if kind in ["rabbit", "deer", "rare_deer", "dummy"] else "rabbit"

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
			var skeletons := animal_mesh.find_children("*","Skeleton3D",true,false)
			if not skeletons.is_empty():
				deer_skeleton = skeletons[0] as Skeleton3D
				for name in ["Front leg.L","Front leg.R","Back leg.L","Back leg.R"]:
					deer_legs.append(deer_skeleton.find_bone(name))
				for name in ["Front shin.L","Front shin.R","Back shin.L","Back shin.R"]:
					deer_shins.append(deer_skeleton.find_bone(name))
		body.add_child(animal_mesh)
		_create_health_bar()
		if species == "rare_deer":
			var marker := Label3D.new()
			marker.name = "RareWildlifeLabel"
			marker.text = "★ РЕДКИЙ ОЛЕНЬ"
			marker.position.y = 2.32
			marker.font_size = 35
			marker.modulate = Color("ffe28e")
			add_child(marker)
	last_position = position

func _create_health_bar() -> void:
	var label_height := 2.0 if species in ["deer","rare_deer"] else 0.9
	var back := BoxMesh.new()
	back.size = Vector3(0.9,0.085,0.05)
	health_track = MeshInstance3D.new()
	health_track.name = "HealthTrack"
	health_track.mesh = back
	health_track.position.y = label_height
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color("291b20")
	health_track.material_override = dark
	add_child(health_track)
	health_fill = MeshInstance3D.new()
	health_fill.name = "HealthFill"
	var bar := BoxMesh.new()
	bar.size = Vector3(0.86,0.065,0.06)
	health_fill.mesh = bar
	health_fill.position = Vector3(0,label_height,0.01)
	var green := StandardMaterial3D.new()
	green.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	green.albedo_color = Color("9bd37c")
	health_fill.material_override = green
	add_child(health_fill)

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
	var previous_life := life
	var travelled := position.distance_to(at)
	if not active or position.distance_to(at) > 7.0:
		position = at
	else:
		position = position.lerp(at,0.55)
	active = true
	visible = alive
	life = clampf(float(hp)/(24.0 if species == "rabbit" else 100.0 if species == "dummy" else 95.0 if species == "rare_deer" else 55.0),0.0,1.0)
	if species != "dummy":
		if alive and not was_alive:
			presentation.reset(body)
			presentation.clear_corpses()
		elif alive and life < previous_life:
			presentation.hit(self, body)
		elif not alive and was_alive:
			presentation.death(self, body)
	was_alive = alive
	if health_track != null:
		health_track.visible = alive
		health_fill.visible = health_track.visible
		health_fill.scale.x = maxf(0.001,life)
		health_fill.position.x = -(1.0-life)*0.43
	if direction.length_squared() > 0.01:
		target_yaw = atan2(-direction.x,-direction.z)
	# Server sends velocity direction only while walking/fleeing. Keep animation
	# decoupled from network frame cadence and don't animate dead creatures.
	if species != "dummy":
		speed_visual = minf(4.5,travelled / 0.30) if direction.length_squared() > 0.01 else 0.0
	last_position = at

func _process(delta: float) -> void:
	presentation.step(self, delta, was_alive and speed_visual > 0.1, global_position)
	if body != null and visible:
		if species == "dummy":
			return
		rotation.y = lerp_angle(rotation.y,target_yaw,minf(1.0,delta*5.0))
		stride_clock += delta * lerpf(2.2,10.0,speed_visual)
		if species == "rabbit":
			# Short hops with a planted phase, not a flying/hovering ball.
			var hop := pow(maxf(0.0,sin(stride_clock)),2.0)
			body.position.y = hop * 0.22 * clampf(speed_visual,0.0,1.0)
			body.rotation.x = -0.09 * clampf(speed_visual,0.0,1.0) * cos(stride_clock)
		else:
			_update_deer_gait(delta)
			body.position.y = 0.0

func _exit_tree() -> void:
	presentation.clear_corpses()

func _update_deer_gait(delta: float) -> void:
	if deer_skeleton == null or deer_legs.size() != 4 or deer_shins.size() != 4:
		return
	var target_motion := clampf(speed_visual / 1.4,0.0,1.0)
	deer_motion = move_toward(deer_motion,target_motion,delta*3.0)
	if deer_motion < 0.025:
		if animal_anim != null and not animal_anim.is_playing():
			animal_anim.play("Idle",0.25)
		return
	if animal_anim != null and animal_anim.is_playing():
		animal_anim.stop()
	var running := clampf((speed_visual-1.5)/2.5,0.0,1.0)
	deer_gait += delta*lerpf(5.0,11.0,running)
	var swing := lerpf(0.27,0.48,running)*deer_motion
	for i in 4:
		var leg := deer_legs[i]
		var shin := deer_shins[i]
		if leg < 0 or shin < 0:
			continue
		# Opposite legs alternate in walk; running shifts toward bounding gait.
		var phase := deer_gait + (PI if i == 1 or i == 2 else 0.0)
		phase = lerpf(phase,deer_gait+(PI if i >= 2 else 0.0),running)
		var step := sin(phase)
		deer_skeleton.set_bone_pose_rotation(leg,Quaternion(Vector3.RIGHT,step*swing))
		deer_skeleton.set_bone_pose_rotation(shin,Quaternion(Vector3.RIGHT,maxf(0.0,-step)*swing*0.85))
