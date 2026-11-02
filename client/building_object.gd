extends Node3D
# Simple low-poly camp structures; no external assets or physics dependencies.
const COSTS := {
    "campfire":{"wood":3,"stone":2,"herb":0},
    "tent":{"wood":5,"stone":0,"herb":2}
}
const RADII := {"campfire":1.25,"tent":2.0}
var kind := ""
var building_id := 0
var is_preview := false
var preview_valid := false
var _ghost_material: StandardMaterial3D

func setup(id: int, type: String, location: Vector3) -> void:
    building_id = id
    kind = type
    position = location

static func is_valid_kind(type: String) -> bool:
    return COSTS.has(type)

static func affordable(type: String, inventory: Dictionary) -> bool:
    if not is_valid_kind(type):
        return false
    for item in COSTS[type].keys():
        if int(inventory.get(item,0)) < int(COSTS[type][item]):
            return false
    return true

func _ready() -> void:
    if not is_valid_kind(kind):
        push_error("Invalid building kind")
        return
    if DisplayServer.get_name() == "headless":
        return
    if kind == "campfire":
        _campfire()
    else:
        _tent()
    if is_preview:
        set_preview_valid(preview_valid)

func set_preview_valid(valid: bool) -> void:
    preview_valid = valid
    if DisplayServer.get_name() == "headless":
        return
    if _ghost_material == null:
        _ghost_material = StandardMaterial3D.new()
        _ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        _ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        _ghost_material.no_depth_test = false
        _ghost_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    _ghost_material.albedo_color = Color(0.24,0.92,0.52,0.42) if valid else Color(1.0,0.32,0.27,0.48)
    for child in get_children():
        if child is MeshInstance3D:
            child.material_override = _ghost_material

func _material(color: Color, metallic: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metallic
    mat.roughness = 0.9
    return mat

func _solid(mesh: Mesh, location: Vector3, color: Color, rotations: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.mesh = mesh
    part.position = location
    part.rotation_degrees = rotations
    part.material_override = _material(color)
    add_child(part)
    return part

func _campfire() -> void:
    var rock := SphereMesh.new()
    rock.radius = 0.35
    rock.height = 0.38
    rock.radial_segments = 8
    rock.rings = 4
    for i in range(9):
        var angle := TAU * float(i) / 9.0
        _solid(rock, Vector3(cos(angle)*0.75,0.15,sin(angle)*0.75),
            Color("81877d") if i%2==0 else Color("a4a59a"))
    var log_mesh := CylinderMesh.new()
    log_mesh.top_radius = 0.18
    log_mesh.bottom_radius = 0.18
    log_mesh.height = 1.8
    log_mesh.radial_segments = 7
    for i in range(3):
        _solid(log_mesh,Vector3(0,0.24,0),Color("634333"),Vector3(0,i*60.0,90))
    var flame := SphereMesh.new()
    flame.radius = 0.35
    flame.height = 0.85
    flame.radial_segments = 9
    flame.rings = 5
    var flame_part := _solid(flame,Vector3(0,0.66,0),Color("ed6a2a"))
    var flame_material: StandardMaterial3D = flame_part.material_override
    flame_material.emission_enabled = true
    flame_material.emission = Color("ff8c36")
    flame_material.emission_energy_multiplier = 0.8
    var tip := SphereMesh.new()
    tip.radius = 0.17
    tip.height = 0.56
    tip.radial_segments = 9
    var tip_part := _solid(tip,Vector3(0,0.96,0),Color("ffe0a0"))
    var tip_material: StandardMaterial3D = tip_part.material_override
    tip_material.emission_enabled = true
    tip_material.emission = Color("ffd38c")
    tip_material.emission_energy_multiplier = 0.6

func _tent() -> void:
    # Ridge tent consisting of two pitched cloth surfaces and end panels.
    var fabric := SurfaceTool.new()
    fabric.begin(Mesh.PRIMITIVE_TRIANGLES)
    var a := Vector3(-1.5,0,-1.3)
    var b := Vector3(1.5,0,-1.3)
    var c := Vector3(-1.5,0,1.3)
    var d := Vector3(1.5,0,1.3)
    var top_front := Vector3(0,2.3,-1.3)
    var top_back := Vector3(0,2.3,1.3)
    for tri in [[a,top_front,top_back],[a,top_back,c],
            [top_front,b,d],[top_front,d,top_back],
            [a,b,top_front],[c,top_back,d]]:
        for v in tri:
            fabric.add_vertex(v)
    fabric.generate_normals()
    var cloth := MeshInstance3D.new()
    cloth.mesh = fabric.commit()
    var mat := _material(Color("bcac75"))
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    cloth.material_override = mat
    add_child(cloth)
    var door := BoxMesh.new()
    door.size = Vector3(0.92,1.32,0.055)
    _solid(door,Vector3(0,0.66,-1.34),Color("474034"))
    var pole := CylinderMesh.new()
    pole.top_radius = 0.08
    pole.bottom_radius = 0.08
    pole.height = 2.65
    for z in [-1.38,1.38]:
        _solid(pole,Vector3(0,1.2,z),Color("725037"))
