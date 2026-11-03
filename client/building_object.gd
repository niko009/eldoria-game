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
var _high_detail := true

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

func set_visual_detail(high: bool) -> void:
    _high_detail = high
    # Cap active MeshInstances for Android Low. These are decorations only,
    # never resource nodes, colliders or server-side gameplay entities.
    var optional_names := [
        "CookingSupport", "CookingPot", "CookingPotLid",
        "Bedroll", "BedPillow", "SupplyChest", "SupplyLid", "SupplyBuckle"]
    for item in get_children():
        if item is MeshInstance3D and (
                str(item.name).begins_with("Ember") or str(item.name) in optional_names):
            item.visible = high

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
    # The footprint and world/collision logic remain untouched. All extra
    # geometry is decorative and uses inexpensive opaque mobile materials.
    var ash_ring := TorusMesh.new()
    ash_ring.inner_radius = 0.52
    ash_ring.outer_radius = 0.87
    ash_ring.rings = 4
    ash_ring.ring_segments = 16
    _solid(ash_ring, Vector3(0, 0.065, 0), Color("433b32"))
    var coal_mesh := CylinderMesh.new()
    coal_mesh.top_radius = 0.32
    coal_mesh.bottom_radius = 0.41
    coal_mesh.height = 0.11
    coal_mesh.radial_segments = 10
    _solid(coal_mesh, Vector3(0, 0.11, 0), Color("482e2b"))
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
    # A small suspended cooking pot makes this recognizable as a lived-in camp,
    # not just an orange cone on the terrain. No additional dynamic lights.
    var support := CylinderMesh.new()
    support.top_radius = 0.027
    support.bottom_radius = 0.027
    support.radial_segments = 5
    support.height = 1.22
    _solid(support, Vector3(0.52, 1.13, 0.25), Color("5c4940"), Vector3(0, 0, -24)).name = "CookingSupport"
    var pot_mesh := SphereMesh.new()
    pot_mesh.radius = 0.25
    pot_mesh.height = 0.36
    pot_mesh.radial_segments = 10
    pot_mesh.rings = 5
    _solid(pot_mesh, Vector3(0.33, 0.73, 0.24), Color("424d4a")).name = "CookingPot"
    var lid := CylinderMesh.new()
    lid.top_radius = 0.18
    lid.bottom_radius = 0.20
    lid.height = 0.048
    lid.radial_segments = 10
    _solid(lid, Vector3(0.33, 0.94, 0.24), Color("b7a17c")).name = "CookingPotLid"
    var flame := CylinderMesh.new()
    flame.bottom_radius = 0.38
    flame.top_radius = 0.015
    flame.height = 0.95
    flame.radial_segments = 9
    flame.rings = 3
    var flame_part := _solid(flame,Vector3(0,0.66,0),Color("ed6a2a"))
    var flame_material := ShaderMaterial.new()
    flame_material.shader = preload("res://shaders/camp_flame.gdshader")
    flame_part.material_override = flame_material
    flame_part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var tip := CylinderMesh.new()
    tip.bottom_radius = 0.19
    tip.top_radius = 0.01
    tip.height = 0.72
    tip.radial_segments = 7
    tip.rings = 2
    var tip_part := _solid(tip,Vector3(0.10,0.62,0.12),Color("ffe0a0"))
    var core := ShaderMaterial.new()
    core.shader = flame_material.shader
    core.set_shader_parameter("flame_color",Color("ffda84"))
    tip_part.material_override = core
    tip_part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # Amber embers glow without creating expensive mobile point-light shadows.
    var ember := SphereMesh.new()
    ember.radius = 0.095
    ember.height = 0.11
    ember.radial_segments = 6
    ember.rings = 3
    for at in [Vector3(-0.27, 0.2, 0.21), Vector3(0.22, 0.19, -0.18)]:
        var piece := _solid(ember, at, Color("ffb36a"))
        piece.name = "Ember"
        var glow := _material(Color("ffba68"))
        glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        piece.material_override = glow
        piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _tent() -> void:
    # Folded canvas with an open entrance; dimensions preserve the building footprint.
    var fabric := SurfaceTool.new()
    fabric.begin(Mesh.PRIMITIVE_TRIANGLES)
    for side in [-1.0,1.0]:
        for strip in range(4):
            for row in range(8):
                var vertices: Array[Vector3] = []
                for offset in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
                    var u := float(strip+offset.x)/4.0
                    var z := -1.3 + float(row+offset.y)*2.6/8.0
                    var sag := sin(u*PI)*0.15 + sin(z*8.0)*sin(u*PI)*0.045
                    vertices.append(Vector3(side*u*1.5,2.3*(1.0-u)-sag,z))
                for i in [0,1,2,0,2,3]:
                    fabric.set_color(Color("c6ad7c") if row%2 == 0 else Color("bda173"))
                    fabric.add_vertex(vertices[i])
    # Rear canvas and two tied-back entrance flaps on the camera-facing side.
    for triangle in [[Vector3(-1.5,0,-1.3),Vector3(0,2.3,-1.3),Vector3(1.5,0,-1.3)],
            [Vector3(-1.5,0,1.3),Vector3(0,2.3,1.3),Vector3(-0.62,0.15,1.38)],
            [Vector3(0,2.3,1.3),Vector3(1.5,0,1.3),Vector3(0.62,0.15,1.38)]]:
        for v in triangle:
            fabric.set_color(Color("cdb78c"))
            fabric.add_vertex(v)
    fabric.generate_normals()
    var cloth := MeshInstance3D.new()
    cloth.mesh = fabric.commit()
    var mat := _material(Color.WHITE)
    mat.vertex_color_use_as_albedo = true
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    cloth.material_override = mat
    add_child(cloth)
    var floor_mesh := BoxMesh.new()
    floor_mesh.size = Vector3(2.5,0.04,2.4)
    _solid(floor_mesh,Vector3(0,0.03,0),Color("514538"))
    var pole := CylinderMesh.new()
    pole.top_radius = 0.07
    pole.bottom_radius = 0.09
    pole.height = 2.55
    pole.radial_segments = 6
    for z in [-1.38,1.38]:
        _solid(pole,Vector3(0,1.22,z),Color("725037"))
    # Shared trim mesh keeps ropes and seams to one draw call.
    var trim := SurfaceTool.new()
    trim.begin(Mesh.PRIMITIVE_TRIANGLES)
    for z in [-1.32,1.32]:
        _beam(trim,Vector3(-1.5,0.03,z),Vector3(0,2.3,z),0.025,Color("79684b"))
        _beam(trim,Vector3(1.5,0.03,z),Vector3(0,2.3,z),0.025,Color("79684b"))
        for side in [-1.0,1.0]:
            var peg := Vector3(side*1.85,0.04,z)
            _beam(trim,Vector3(side*0.9,0.9,z),peg,0.012,Color("e1cc9c"))
            _beam(trim,peg,peg+Vector3(0,0.18,0),0.035,Color("654c32"))
    trim.generate_normals()
    var details := MeshInstance3D.new()
    details.mesh = trim.commit()
    details.material_override = mat
    add_child(details)
    _tent_decor(mat)

func _tent_decor(shared_cloth: StandardMaterial3D) -> void:
    # A roof medallion and a warm embroidered band add a focal point to the
    # fabric without a costly alpha texture or new UV/material dependencies.
    var accent := SurfaceTool.new()
    accent.begin(Mesh.PRIMITIVE_TRIANGLES)
    for side: float in [-1.0, 1.0]:
        # Broad ochre canvas bands follow the original folded roof, offset
        # slightly along its outward normal to avoid z-fighting on Android.
        for band in [[0.67, 0.79, Color("8d6653")],
                [0.63, 0.66, Color("e0c08b")]]:
            var u0: float = band[0]
            var u1: float = band[1]
            var c: Color = band[2]
            var a0 := _tent_roof_point(side,u0,-1.23)
            var a1 := _tent_roof_point(side,u1,-1.23)
            var b0 := _tent_roof_point(side,u0,1.23)
            var b1 := _tent_roof_point(side,u1,1.23)
            _tri(accent,a0,a1,b1,c)
            _tri(accent,a0,b1,b0,c)
        var x: float = side * 1.08
        var y: float = 0.59
        for z: float in [-0.85, -0.40, 0.05, 0.50]:
            var a: Vector3 = Vector3(x, y, z)
            var b: Vector3 = Vector3(x + side*0.09, y - 0.14, z + 0.22)
            var c: Vector3 = Vector3(x, y, z + 0.45)
            _tri(accent, a, b, c, Color("7f654b"))
    # Bright stitched knot above the triangular entrance.
    _tri(accent, Vector3(-0.22,1.92,1.333), Vector3(0,2.2,1.34),
        Vector3(0.22,1.92,1.333), Color("e1c989"))
    accent.generate_normals()
    var marks := MeshInstance3D.new()
    marks.name = "CanvasEmbroideries"
    marks.mesh = accent.commit()
    marks.material_override = shared_cloth
    add_child(marks)

    # Woven bedroll and a tiny supplies chest fit strictly inside the existing
    # radius. They are decoration: no collisions or new interactable objects.
    var bed := BoxMesh.new()
    bed.size = Vector3(1.02, 0.11, 1.30)
    _solid(bed, Vector3(-0.47, 0.14, 0.20), Color("738c77")).name = "Bedroll"
    var pillow := BoxMesh.new()
    pillow.size = Vector3(0.82, 0.13, 0.30)
    _solid(pillow, Vector3(-0.47, 0.24, -0.33), Color("d5bd8f")).name = "BedPillow"
    var chest := BoxMesh.new()
    chest.size = Vector3(0.62, 0.46, 0.51)
    _solid(chest, Vector3(0.68, 0.25, -0.70), Color("704a32")).name = "SupplyChest"
    var chest_lid := BoxMesh.new()
    chest_lid.size = Vector3(0.66, 0.09, 0.55)
    _solid(chest_lid, Vector3(0.68, 0.52, -0.70), Color("a07e52")).name = "SupplyLid"
    var buckle := BoxMesh.new()
    buckle.size = Vector3(0.1, 0.20, 0.02)
    _solid(buckle, Vector3(0.68, 0.42, -0.41), Color("d4b67c")).name = "SupplyBuckle"

func _tent_roof_point(side: float, u: float, z: float) -> Vector3:
    var sag := sin(u * PI) * 0.15 + sin(z * 8.0) * sin(u * PI) * 0.045
    return Vector3(side * (u*1.5+0.035), 2.3*(1.0-u)-sag+0.035, z)

func _tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
    for vertex in [a, b, c]:
        surface.set_color(color)
        surface.add_vertex(vertex)

func _beam(surface: SurfaceTool, start: Vector3, finish: Vector3, radius: float, color: Color) -> void:
    var direction := (finish-start).normalized()
    var tangent := direction.cross(Vector3.FORWARD).normalized()*radius
    var other := direction.cross(tangent).normalized()*radius
    for face in range(4):
        var angle := float(face)*TAU/4.0
        var next := float(face+1)*TAU/4.0
        var a := tangent*cos(angle)+other*sin(angle)
        var b := tangent*cos(next)+other*sin(next)
        for point in [start+a,start+b,finish+b,start+a,finish+b,finish+a]:
            surface.set_color(color)
            surface.add_vertex(point)
