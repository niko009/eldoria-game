extends MultiMeshInstance3D
# Permanent, small axe-cut markers on trees with 1-3 wood removed.
# One draw call per damaged tree, and no material/shader changes to batched GLTF.
const HIT_COUNT := 4
var hits := 0
var _local_radius := 0.37
static var _cut_mesh: BoxMesh
static var _bark_material: StandardMaterial3D

func configure(tree_scale: float, quantity_left: int) -> void:
    _local_radius = 0.37 * tree_scale
    hits = clampi(HIT_COUNT - quantity_left,0,3)

func _ready() -> void:
    if DisplayServer.get_name() == "headless":
        return
    if _cut_mesh == null:
        _cut_mesh = BoxMesh.new()
        _cut_mesh.size = Vector3(0.065,0.32,0.045)
    if _bark_material == null:
        _bark_material = StandardMaterial3D.new()
        _bark_material.albedo_color = Color("654027")
        _bark_material.roughness = 1.0
    var mesh_for_marks := _cut_mesh
    mesh_for_marks.material = _bark_material
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = mesh_for_marks
    mm.instance_count = 6
    multimesh = mm
    update_hits(hits)

func update_hits(new_hits: int) -> void:
    hits = clampi(new_hits,0,3)
    if multimesh == null:
        return
    for i in range(6):
        var hit := i / 2
        if hit >= hits:
            multimesh.set_instance_transform(i,Transform3D(Basis().scaled(Vector3.ZERO),Vector3.ZERO))
            continue
        var around := float(hit)*TAU/3.0
        var offset := Vector3(sin(around)*_local_radius,0,cos(around)*_local_radius)
        var pos := offset + Vector3(0,0.55+float(hit)*0.28,0)
        var skew := -0.62 if i%2==0 else 0.62
        var facing := Basis(Vector3.UP,around)
        var lean := Basis(Vector3.FORWARD,skew)
        multimesh.set_instance_transform(i,Transform3D(facing*lean,pos))
