extends Node3D
class_name EldoriaWolfActor

# Lightweight placeholder for first PvE milestone, no external art.
var body: Node3D
var health_bar: MeshInstance3D
var visual_hp := 60
var down := false

func _ready() -> void:
    body = Node3D.new()
    add_child(body)
    var fur := StandardMaterial3D.new()
    fur.albedo_color = Color(0.39, 0.34, 0.28)
    var dark := StandardMaterial3D.new()
    dark.albedo_color = Color(0.22, 0.20, 0.18)
    var eyes := StandardMaterial3D.new()
    eyes.albedo_color = Color(0.88, 0.65, 0.25)
    _part("Body", Vector3(0, 0.62, 0), Vector3(0.65, 0.48, 1.12), fur)
    _part("Head", Vector3(0, 0.77, -0.68), Vector3(0.46, 0.43, 0.53), fur)
    _part("Muzzle", Vector3(0, 0.66, -1.02), Vector3(0.28, 0.24, 0.35), dark)
    for side in [-1.0, 1.0]:
        _part("Ear", Vector3(side * 0.22, 1.10, -0.70), Vector3(0.20, 0.31, 0.20), dark)
        _part("Eye", Vector3(side * 0.20, 0.88, -0.95), Vector3(0.09, 0.08, 0.10), eyes)
        for z in [-0.37, 0.36]:
            _part("Leg", Vector3(side * 0.25, 0.27, z), Vector3(0.17, 0.52, 0.18), dark)
    _part("Tail", Vector3(0, 0.80, 0.73), Vector3(0.26, 0.22, 0.57), fur)
    var back := StandardMaterial3D.new()
    back.albedo_color = Color(0.3, 0.10, 0.10)
    health_bar = _part("Health", Vector3(0, 1.51, 0), Vector3(0.9, 0.075, 0.08), back)
    _update_health()

func _part(label: String, at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = label
    part.mesh = BoxMesh.new()
    part.mesh.size = dimensions
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
    _update_health()

func _update_health() -> void:
    if health_bar == null:
        return
    health_bar.scale.x = maxf(0.01, float(visual_hp) / 60.0)
