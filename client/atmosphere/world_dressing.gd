extends Node3D
## Visual pass with an independent seed. Never creates or reorders resources.
## Solid landmark footprints are appended identically on clients and server.
const SEED := 870708
var world: Node3D
var batches: Array[MultiMeshInstance3D] = []
var landmarks: Array[Vector3] = []
var _rng := RandomNumberGenerator.new()
var _groups: Dictionary = {}
var _meshes: Dictionary = {}
var _solid_surfaces: Dictionary = {}
var _materials: Dictionary = {}
var _fireflies: MultiMeshInstance3D
var _clock := 0.0
var _high := true
var _backdrops: Array[StandardMaterial3D] = []
var _last_sun := -1.0

func build(forest: Node3D) -> void:
    world = forest
    name = "WorldDressing"
    _rng.seed = SEED
    _materials["stone"] = _material(Color("657d7a"))
    _materials["bark"] = _material(Color("574a36"))
    _materials["wood"] = _material(Color("b8a579"))
    _materials["moss"] = _material(Color("657d40"))
    _materials["rune"] = _material(Color("8edaca"))
    _materials["rune"].emission_enabled = true
    _materials["rune"].emission = Color("54a89c")
    _materials["rune"].emission_energy_multiplier = 0.65
    for key in _materials:
        var surface := SurfaceTool.new()
        surface.begin(Mesh.PRIMITIVE_TRIANGLES)
        _solid_surfaces[key] = surface
    _prepare_meshes()
    _tree_silhouettes()
    _understory()
    _trail_edges()
    _landmarks()
    _flush()
    for key in _solid_surfaces:
        var mesh: ArrayMesh = _solid_surfaces[key].commit()
        if mesh.get_surface_count() == 0:
            continue
        var node := MeshInstance3D.new()
        node.name = "Landmark_" + key
        node.mesh = mesh
        node.material_override = _materials[key]
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        add_child(node)
    _make_fireflies()
    for node in world.get_children():
        if node is MeshInstance3D and node.material_override is StandardMaterial3D:
            var material: StandardMaterial3D = node.material_override
            if material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and node.name != "Moonstone pond":
                _backdrops.append(material)
        if node is MultiMeshInstance3D and node.name == "DistantForest_extra":
            _backdrops.append(node.multimesh.mesh.surface_get_material(0))

func _material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 1.0
    return material

func _prepare_meshes() -> void:
    for id in ["Fern_1", "Bush_Common", "Grass_Wispy_Tall"]:
        var packed: PackedScene = load("res://assets/nature/" + id + ".gltf")
        var root := packed.instantiate()
        var source := root.get_child(0) as MeshInstance3D
        _meshes[id] = {"mesh":source.mesh, "transform":source.transform}
        root.free()
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for blade in 7:
        var angle := float(blade) * 2.399
        var base := Vector3(cos(angle), 0, sin(angle)) * 0.22
        var tip := base + Vector3(cos(angle)*0.18, 0.28 + 0.06*(blade%3), sin(angle)*0.18)
        var side := Vector3(cos(angle+PI/2),0,sin(angle+PI/2))*0.035
        for point in [base-side,base+side,tip]:
            surface.set_color(Color("879951") if point.y > 0.1 else Color("425a35"))
            surface.add_vertex(point)
    surface.generate_normals()
    var grass := surface.commit()
    var material := _material(Color.WHITE)
    material.vertex_color_use_as_albedo = true
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    grass.surface_set_material(0, material)
    _meshes["tuft"] = {"mesh":grass, "transform":Transform3D.IDENTITY}
    var pebble := SphereMesh.new()
    pebble.radius = 0.18
    pebble.height = 0.19
    pebble.radial_segments = 7
    pebble.rings = 3
    pebble.material = _materials["stone"]
    _meshes["pebble"] = {"mesh":pebble,"transform":Transform3D.IDENTITY}
    var petal := SphereMesh.new()
    petal.radius = 0.065
    petal.height = 0.08
    petal.radial_segments = 5
    petal.rings = 3
    petal.material = _material(Color("dfcaa0"))
    _meshes["blossom"] = {"mesh":petal,"transform":Transform3D.IDENTITY}

func _allowed(p: Vector2) -> bool:
    if p.length() < 7.0 or p.length() > 86.0:
        return false
    if absf(p.x - sin(p.y*0.081)*5.0) < 2.85:
        return false
    if p.distance_to(Vector2(-29,22)) < 13.0:
        return false
    for resource in world.resources:
        var at: Vector3 = resource["pos"]
        if p.distance_squared_to(Vector2(at.x,at.z)) < 1.25:
            return false
    return true

func _tree_silhouettes() -> void:
    # Retain every trunk position, horizontal footprint and harvest identity.
    # Taller eastern conifers and broader-looking western crowns use existing
    # meshes; restoration uses the same updated transform, so no ghost canopy.
    for key in world._batch_nodes_by_key:
        var model: String = str(key).split("#")[0]
        if not model in world.TREE_MODELS:
            continue
        var batch: MultiMeshInstance3D = world._batch_nodes_by_key[key]
        for i in batch.multimesh.instance_count:
            var transform: Transform3D = world._batch_original_transforms[key][i]
            var variation := 0.92+0.15*(0.5+0.5*sin(transform.origin.x*0.37+transform.origin.z*0.61))
            if model.begins_with("Pine") and transform.origin.x > 8:
                variation += 0.15
            transform.basis = transform.basis.scaled_local(Vector3(1,variation,1))
            batch.multimesh.set_instance_transform(i,transform)
            world._batch_original_transforms[key][i] = transform

func _scatter(id: String, p: Vector2, scale_value: float, extra: bool, lift: float = 0.0) -> void:
    var key := id + ("_extra" if extra else "_core")
    if not _groups.has(key):
        _groups[key] = []
    var at := Vector3(p.x,world.height_at(p.x,p.y)+lift,p.y)
    var basis := Basis(Vector3.UP,_rng.randf()*TAU).scaled(Vector3.ONE*scale_value)
    _groups[key].append(Transform3D(basis,at)*_meshes[id]["transform"])

func _understory() -> void:
    # Elliptical colonies leave open glades between them. Eastern fernwoods,
    # western warm meadows, and a sparse northern rocky belt read differently.
    for colony in 150:
        var center := Vector2(_rng.randf_range(-76,76),_rng.randf_range(-76,76))
        var radius := _rng.randf_range(2.5,7.0)
        for detail in 60:
            var angle := _rng.randf()*TAU
            var distance := sqrt(_rng.randf())*radius
            var p := center + Vector2(cos(angle),sin(angle)*0.68)*distance
            if not _allowed(p):
                continue
            var extra := detail % 6 != 0
            _scatter("tuft",p,_rng.randf_range(0.7,1.5),extra)
            if detail % 18 == 0:
                var id := "Fern_1" if center.x > 8 else "Grass_Wispy_Tall"
                _scatter(id,p,_rng.randf_range(0.18,0.38),true)
            if detail == 0:
                _scatter("Bush_Common",p,_rng.randf_range(0.20,0.34),true)
            if detail % 7 == 0 and center.x < 8:
                _scatter("blossom",p,1.0,extra,0.24)
            if detail % 11 == 0:
                _scatter("pebble",p,_rng.randf_range(0.5,1.8),extra,0.02)
        # Low silhouettes, not fake harvestable trees. All are step-height.
        if colony % 4 == 0 and _allowed(center):
            var at := Vector3(center.x,world.height_at(center.x,center.y),center.y)
            _log(at, _rng.randf()*TAU, _rng.randf_range(0.7,1.3))

func _trail_edges() -> void:
    for i in 280:
        var z := _rng.randf_range(-70,70)
        var side := -1.0 if i%2 == 0 else 1.0
        var p := Vector2(sin(z*0.081)*5.0+side*_rng.randf_range(2.9,4.0),z)
        if _allowed(p):
            _scatter("tuft",p,_rng.randf_range(0.5,1.0),i%3!=0)
            if i%5 == 0:
                _scatter("pebble",p,0.7,false,0.02)
    # Reed/stone colonies follow the actual shore rather than an even grid.
    for i in 110:
        var a := _rng.randf()*TAU
        var p := Vector2(-29,22)+Vector2(cos(a),sin(a))*_rng.randf_range(13.1,15.5)
        if _allowed(p):
            _scatter("Grass_Wispy_Tall",p,0.38,true)

func _piece(mesh: Mesh, at: Vector3, scale_value: Vector3, key: String, rotation: Vector3 = Vector3.ZERO) -> void:
    var transform := Transform3D(Basis.from_euler(rotation).scaled(scale_value),at)
    _solid_surfaces[key].append_from(mesh,0,transform)

func _log(at: Vector3, angle: float, size: float) -> void:
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.11
    cylinder.bottom_radius = 0.14
    cylinder.height = 1.6
    cylinder.radial_segments = 8
    var rotation := Vector3(PI/2,angle,0)
    _piece(cylinder,at+Vector3.UP*0.10,Vector3.ONE*size,"bark",rotation)
    cylinder.height = 0.025
    var offset := Basis.from_euler(rotation)*Vector3(0,0.8*size,0)
    _piece(cylinder,at+Vector3.UP*0.10+offset,Vector3.ONE*size,"wood",rotation)
    var stump := CylinderMesh.new()
    stump.top_radius = 0.22
    stump.bottom_radius = 0.32
    stump.height = 0.22
    stump.radial_segments = 9
    _piece(stump,at+Vector3(0.7,0.10,0.5),Vector3.ONE,"bark")
    stump.height = 0.025
    _piece(stump,at+Vector3(0.7,0.22,0.5),Vector3.ONE,"wood")
    # Small exposed roots/branches, below character step height.
    for j in 3:
        cylinder.height = 0.9
        _piece(cylinder,at+Vector3(j*0.25,0.025,0.3),Vector3(0.3,1,0.3),"bark",Vector3(PI/2,angle+j,0))

func _landmark_site(wanted: Vector2) -> Vector3:
    # Reserve a clear 5 m patch, preserving access to every existing resource.
    for i in 160:
        var p := wanted + Vector2(cos(i*2.4),sin(i*2.4))*sqrt(float(i))*0.65
        var clear := absf(p.x-sin(p.y*0.081)*5.0)>8.0
        for resource in world.resources:
            var at: Vector3 = resource["pos"]
            if p.distance_squared_to(Vector2(at.x,at.z)) < 30.25:
                clear = false
                break
        if clear:
            var at := Vector3(p.x,world.height_at(p.x,p.y),p.y)
            landmarks.append(at)
            return at
    push_error("TASK087: no safe landmark site")
    return Vector3.ZERO

func _column(at: Vector3, height: float, radius: float) -> void:
    at.y = world.height_at(at.x,at.z)-0.04
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for ring in 4:
        for side in 7:
            var corners: Array[Vector3] = []
            for offset in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,1),Vector2i(1,0)]:
                var level: int = ring+offset.x
                var angle := TAU*float(side+offset.y)/7.0
                var taper := [1.0,0.88,0.92,0.78,0.63][level] as float
                var width := radius*taper*(0.9+0.08*sin(angle*3.0+level))
                corners.append(Vector3(cos(angle)*width,float(level)*height/4.0,sin(angle)*width))
            for index in [0,1,2,0,2,3]:
                surface.add_vertex(corners[index])
    surface.generate_normals()
    # The shared stone surface also receives indexed primitive meshes. Index
    # this custom mesh too, otherwise its sides vanish from the merged draw.
    surface.index()
    _piece(surface.commit(),at,Vector3.ONE,"stone")
    world._add_obstacle(Vector2(at.x,at.z),radius)
    var column := CylinderMesh.new()
    column.height = 0.09
    column.top_radius = radius*0.64
    column.bottom_radius = radius*0.71
    column.radial_segments = 7
    _piece(column,at+Vector3.UP*(height+0.025),Vector3.ONE,"moss")
    # Fracture bands and weathered footings break the uniform cylinder outline.
    column.top_radius = radius*0.98
    column.bottom_radius = radius
    _piece(column,at+Vector3.UP*0.13,Vector3.ONE,"moss")
    column.height = 0.14
    column.top_radius = radius*0.9
    _piece(column,at+Vector3.UP*(height*0.57),Vector3.ONE,"stone")

func _landmarks() -> void:
    var arch := _landmark_site(Vector2(-23,-24))
    var box := BoxMesh.new()
    box.size = Vector3.ONE
    for side in [-1.0,1.0]:
        _column(arch+Vector3(side*2.3,0,0),3.8,0.65)
        _piece(box,arch+Vector3(side*1.35,4.05,0),Vector3(2.0,0.55,1.15),"stone",Vector3(0,0,-side*0.12))
    _piece(box,arch+Vector3(0,4.3,0),Vector3(0.8,0.9,1.25),"stone")
    for i in 5:
        _piece(box,arch+Vector3(-1.4+i*0.7,0.07,2.0),Vector3(0.55,0.12,0.8),"stone")
        _piece(box,arch+Vector3(-1.4+i*0.7,0.14,2.0),Vector3(0.05,0.015,0.45),"rune")
    var altar := _landmark_site(Vector2(29,13))
    for i in 5:
        var a := TAU*float(i)/5.0
        var p := altar+Vector3(cos(a)*2.9,0,sin(a)*2.9)
        _column(p,1.5+0.35*(i%3),0.45)
        _piece(box,p+Vector3(0,1.2,-0.41),Vector3(0.08,0.45,0.04),"rune")
    var torus := TorusMesh.new()
    torus.inner_radius = 1.4
    torus.outer_radius = 1.49
    torus.rings = 24
    torus.ring_segments = 6
    _piece(torus,altar+Vector3.UP*0.10,Vector3(1,0.3,1),"rune")
    var crystal := PrismMesh.new()
    crystal.size = Vector3(0.7,1.5,0.7)
    _piece(crystal,altar+Vector3.UP*3.2,Vector3.ONE,"rune",Vector3(0,0.4,0.2))
    var camp := _landmark_site(Vector2(-36,39))
    for i in 3:
        _log(camp+Vector3(-2+i*1.8,0,1.5),0.3+i,1.1)
    for i in 11:
        var a := float(i)*TAU/11
        var stone := SphereMesh.new()
        stone.radius = 0.23
        stone.height = 0.2
        stone.radial_segments = 7
        stone.rings = 3
        _piece(stone,camp+Vector3(cos(a),0.09,sin(a)),Vector3.ONE,"stone")
    _column(camp+Vector3(-2.6,0,-1.5),2.0,0.45)
    _piece(box,camp+Vector3(-2.6,1.7,-1.5),Vector3(1.7,0.35,0.16),"wood",Vector3(0,0,0.13))

func _flush() -> void:
    for key in _groups:
        var id: String = key.trim_suffix("_extra").trim_suffix("_core")
        var instances := MultiMesh.new()
        instances.transform_format = MultiMesh.TRANSFORM_3D
        instances.mesh = _meshes[id]["mesh"]
        instances.instance_count = _groups[key].size()
        for i in instances.instance_count:
            instances.set_instance_transform(i,_groups[key][i])
        var draw := MultiMeshInstance3D.new()
        draw.name = key
        draw.multimesh = instances
        draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        draw.visibility_range_end = 58.0 if key.ends_with("_extra") else 75.0
        add_child(draw)
        batches.append(draw)

func _make_fireflies() -> void:
    var mesh := SphereMesh.new()
    mesh.radius = 0.025
    mesh.height = 0.05
    mesh.radial_segments = 4
    mesh.rings = 2
    var material := _material(Color("c2df9c"))
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mesh.material = material
    var instances := MultiMesh.new()
    instances.transform_format = MultiMesh.TRANSFORM_3D
    instances.mesh = mesh
    instances.instance_count = 24
    _fireflies = MultiMeshInstance3D.new()
    _fireflies.name = "Fireflies"
    _fireflies.multimesh = instances
    _fireflies.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _fireflies.visibility_range_end = 35
    _fireflies.visible = false
    add_child(_fireflies)

func apply_quality(high: bool) -> void:
    _high = high
    for batch in batches:
        batch.visible = high or not batch.name.ends_with("_extra")
        batch.visibility_range_end = (58.0 if batch.name.ends_with("_extra") else 75.0) if high else 40.0
    if not high:
        _fireflies.visible = false

func _process(delta: float) -> void:
    if world != null and not is_equal_approx(_last_sun,world.sun.light_energy):
        _last_sun = world.sun.light_energy
        var night := clampf((0.82-_last_sun)/0.40,0,1)
        for material in _backdrops:
            material.albedo_color = Color.WHITE.lerp(Color("536d8a"),night)
    if _fireflies == null:
        return
    _fireflies.visible = _high and world.sun.light_energy < 0.5
    if not _fireflies.visible:
        return
    _clock += delta
    for i in 24:
        var p := Vector2(18+sin(i*2.4+_clock*0.12)*8,12+cos(i*1.7+_clock*0.09)*8)
        var at := Vector3(p.x,world.height_at(p.x,p.y)+0.7+sin(_clock+i)*0.35,p.y)
        _fireflies.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY,at))
