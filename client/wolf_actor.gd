extends Node3D
class_name EldoriaWolfActor

# Lightweight placeholder for first PvE milestone, no external art.
var body: Node3D
var health_bar: MeshInstance3D
var visual_hp := 60
var down := false
var stride := 0.0
var moving := false
var legs: Array[MeshInstance3D] = []
var tail: MeshInstance3D

func _ready() -> void:
    body = Node3D.new()
    add_child(body)
    var fur := StandardMaterial3D.new()
    fur.albedo_color = Color(0.39, 0.34, 0.28)
    var dark := StandardMaterial3D.new()
    dark.albedo_color = Color(0.22, 0.20, 0.18)
    var eyes := StandardMaterial3D.new()
    eyes.albedo_color = Color(0.88, 0.65, 0.25)
    _part("Body", Vector3(0, 0.62, 0), Vector3(0.72, 0.64, 1.20), fur)
    _part("Head", Vector3(0, 0.83, -0.70), Vector3(0.55, 0.49, 0.61), fur)
    _part("Muzzle", Vector3(0, 0.66, -1.02), Vector3(0.31, 0.25, 0.40), dark)
    for side in [-1.0, 1.0]:
        _part("Ear", Vector3(side * 0.22, 1.10, -0.70), Vector3(0.20, 0.35, 0.20), dark)
        _part("Eye", Vector3(side * 0.24, 0.91, -0.94), Vector3(0.09, 0.085, 0.10), eyes)
        for z in [-0.37, 0.36]:
            legs.append(_part("Leg", Vector3(side * 0.25, 0.27, z), Vector3(0.19, 0.57, 0.20), dark))
    tail = _part("Tail", Vector3(0, 0.80, 0.73), Vector3(0.30, 0.24, 0.67), fur)
    var back := StandardMaterial3D.new()
    back.albedo_color = Color(0.3, 0.10, 0.10)
    health_bar = _part("Health", Vector3(0, 1.51, 0), Vector3(0.9, 0.075, 0.08), back)
    _update_health()

func _part(label: String, at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = label
    if label == "Health":
        var bar := BoxMesh.new()
        bar.size = dimensions
        part.mesh = bar
    else:
        var rounded := SphereMesh.new()
        rounded.radius = 0.5
        rounded.height = 1.0
        rounded.radial_segments = 10
        rounded.rings = 5
        part.mesh = rounded
        part.scale = dimensions
    part.material_override = material
    part.position = at
    body.add_child(part)
    return part

func update_state(point: Vector3, hp: int, alive: bool, direction: Vector3 = Vector3.ZERO) -> void:
    position = point
    visual_hp = clampi(hp, 0, 60)
    down = not alive
    visible = alive
    if direction.length_squared() > 0.01:
        rotation.y = atan2(-direction.x, -direction.z)
    moving = alive and direction.length_squared() > 0.01
    _update_health()

func _process(delta: float) -> void:
    if down or body == null:
        return
    stride += delta * (11.0 if moving else 1.4)
    body.position.y = sin(stride * 2.0)*0.045 if moving else 0.0
    for index in legs.size():
        # Diagonal trot. Keep actual collision and position server-owned.
        legs[index].position.y = 0.27 + (sin(stride + (PI if index in [0,3] else 0.0))*0.085 if moving else 0.0)
    if tail != null:
        tail.rotation.y = sin(stride*0.6)*0.18

func _update_health() -> void:
    if health_bar == null:
        return
    health_bar.scale.x = maxf(0.01, float(visual_hp) / 60.0)
