extends RefCounted
# Visual-only scenery: independent seed, no resources or collision changes.

static func build(world: Node3D) -> void:
    _alpine_belt(world)
    _meadow(world)
    _distant_forest(world)

static func _alpine_belt(world: Node3D) -> void:
    var noise := FastNoiseLite.new()
    noise.seed = 82971
    noise.frequency = 0.018
    noise.fractal_octaves = 4
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    const SECTORS := 192
    const RINGS := 12
    for ring in range(RINGS):
        for sector in range(SECTORS):
            var corners: Array[Vector3] = []
            for offset in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
                var t := float(ring + offset.x) / RINGS
                var angle := TAU * float(sector + offset.y) / SECTORS
                var radius := lerpf(99.0, 218.0, t)
                var x := cos(angle) * radius
                var z := sin(angle) * radius
                var ridge := pow(maxf(0.0, sin(t * PI)), 1.4)
                var peaks := 27.0 + 18.0 * sin(angle * 5.0 + 0.4) + 11.0 * sin(angle * 9.0)
                var height := ridge * (peaks + noise.get_noise_2d(x,z) * 27.0) * 0.80
                corners.append(Vector3(x, height - 2.0, z))
            for index in [0,1,2,0,2,3]:
                var vertex := corners[index]
                var tone := Color("526f79").lerp(Color("94adba"), clampf(vertex.y / 50.0,0.0,1.0))
                if vertex.y > 30.0 + noise.get_noise_2d(vertex.x * 3.0,vertex.z * 3.0) * 8.0:
                    tone = tone.lerp(Color("c4d4dc"), 0.62)
                tone = tone.darkened(0.08 + 0.10 * (0.5 + 0.5 * sin(float(sector)*0.7)))
                surface.set_color(tone)
                surface.add_vertex(vertex)
    surface.generate_normals()
    var mesh := MeshInstance3D.new()
    mesh.name = "Continuous alpine ridgelines"
    mesh.mesh = surface.commit()
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.roughness = 1.0
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mesh.material_override = material
    world.add_child(mesh)

static func _meadow(world: Node3D) -> void:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for blade in range(5):
        var angle := float(blade) * 2.4
        var base := Vector3(cos(angle)*0.16,0,sin(angle)*0.16)
        for point in [base + Vector3(-0.06,0,0),base + Vector3(0.06,0,0),base + Vector3(0.10,0.28 + blade*0.025,0.06)]:
            surface.set_color(Color("829c55") if point.y > 0.1 else Color("485e37"))
            surface.add_vertex(point)
    surface.generate_normals()
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.roughness = 1.0
    var grass := surface.commit()
    grass.surface_set_material(0,material)
    var rng := RandomNumberGenerator.new()
    rng.seed = 661231
    var transforms: Array[Transform3D] = []
    for i in range(1800):
        var x := rng.randf_range(-55,55)
        var z := rng.randf_range(-55,55)
        if absf(x - sin(z*0.081)*5.0) < 3.0 or Vector2(x,z).length() < 5.0 or Vector2(x+29,z-22).length() < 14.0:
            continue
        transforms.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU),Vector3(x,world.height_at(x,z)+0.04,z)))
    var instances := MultiMesh.new()
    instances.transform_format = MultiMesh.TRANSFORM_3D
    instances.mesh = grass
    instances.instance_count = transforms.size()
    for i in range(transforms.size()):
        instances.set_instance_transform(i,transforms[i])
    var draw := MultiMeshInstance3D.new()
    draw.name = "Meadow_extra"
    draw.multimesh = instances
    draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    draw.visibility_range_end = 65.0
    world.add_child(draw)
    world.batch_nodes.append(draw)

static func _distant_forest(world: Node3D) -> void:
    # Silhouette trees only beyond the playable world: never counterfeit loot.
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for tier in range(3):
        var bottom := float(tier) * 1.2
        var radius := 1.55 - float(tier) * 0.40
        for side in range(7):
            var a := TAU * float(side) / 7.0
            var b := TAU * float(side+1) / 7.0
            for point in [Vector3(cos(a)*radius,bottom,sin(a)*radius),Vector3(cos(b)*radius,bottom,sin(b)*radius),Vector3(0,bottom+2.9,0)]:
                surface.set_color(Color("416b68").lightened(float(side%3)*0.045))
                surface.add_vertex(point)
    surface.generate_normals()
    var tree := surface.commit()
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    tree.surface_set_material(0,material)
    var noise := FastNoiseLite.new()
    noise.seed = 82971
    noise.frequency = 0.018
    noise.fractal_octaves = 4
    var rng := RandomNumberGenerator.new()
    rng.seed = 328776
    var instances := MultiMesh.new()
    instances.transform_format = MultiMesh.TRANSFORM_3D
    instances.mesh = tree
    instances.instance_count = 850
    for i in range(instances.instance_count):
        var angle := rng.randf() * TAU
        var radius := rng.randf_range(104.0,143.0)
        var x := cos(angle)*radius
        var z := sin(angle)*radius
        var t := (radius-99.0)/119.0
        var ridge := pow(maxf(0.0,sin(t*PI)),1.4)
        var peaks := 27.0+18.0*sin(angle*5.0+0.4)+11.0*sin(angle*9.0)
        var height := ridge*(peaks+noise.get_noise_2d(x,z)*27.0)*0.80-2.1
        var scale := rng.randf_range(0.65,1.3)
        instances.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*scale),Vector3(x,height,z)))
    var draw := MultiMeshInstance3D.new()
    draw.name = "DistantForest_extra"
    draw.multimesh = instances
    draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    world.add_child(draw)
    world.batch_nodes.append(draw)
