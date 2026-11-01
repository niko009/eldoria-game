extends Node3D
# Deterministic stylized landscape with Quaternius CC0 glTF nature assets.
# Identical vegetation positions on Windows and Android; visual quality differs.
const WORLD_RADIUS := 94.0
const TERRAIN_CELLS := 88
const TREE_SEED := 20261101
var tree_leaf_meshes: Array[SphereMesh] = []
var leaf_instances: Array[MeshInstance3D] = []
var asset_tree_count := 0
var asset_detail_count := 0
var _asset_scenes: Dictionary = {}
var _optional_details: Array[Node3D] = []
var _optional_trees: Array[Node3D] = []
var _low_quality := false
const ASSET_ROOT := "res://assets/nature/"
const TREE_MODELS := ["CommonTree_1", "CommonTree_2", "CommonTree_3", "Pine_1", "Pine_2", "Pine_3", "TwistedTree_1", "TwistedTree_2"]
const DETAILS := ["Bush_Common", "Bush_Common_Flowers", "Fern_1", "Grass_Common_Short", "Grass_Wispy_Tall", "Flower_3_Group", "Mushroom_Common"]
const ROCKS := ["Rock_Medium_1", "Rock_Medium_2"]
var _rng := RandomNumberGenerator.new()
var _terrain_noise := FastNoiseLite.new()
var sun: DirectionalLight3D
var environment_node: WorldEnvironment

func _ready() -> void:
    # Clients share a deterministic visual landscape; no RNG calls in gameplay.
    _rng.seed = TREE_SEED
    _terrain_noise.seed = TREE_SEED
    _terrain_noise.frequency = 0.042
    _terrain_noise.fractal_octaves = 3
    _load_asset_scenes()
    _create_sky()
    _create_terrain()
    _create_mountain_silhouette()
    _create_path()
    _create_water()
    _create_trees()
    _create_rocks_and_flowers()
    _create_landmark()

func height_at(x: float, z: float) -> float:
    var radius := Vector2(x, z).length()
    var blend := smoothstep(13.0, 53.0, radius)
    var ripple := sin(x * 0.115) * 2.2 + cos(z * 0.085) * 1.6
    return blend * (1.8 + ripple + _terrain_noise.get_noise_2d(x, z) * 4.8)

func _mat(color: Color, rough: float = 0.94) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = rough
    return m

func _create_sky() -> void:
    sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-37, -34, 0)
    sun.light_color = Color("fff0d4")
    sun.light_energy = 0.95
    sun.shadow_enabled = true
    add_child(sun)
    environment_node = WorldEnvironment.new()
    var e := Environment.new()
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color("70a9cf")
    sky_mat.sky_horizon_color = Color("d5e5da")
    sky_mat.ground_bottom_color = Color("546a5c")
    sky_mat.ground_horizon_color = Color("acbead")
    sky_mat.sun_angle_max = 10.0
    sky.sky_material = sky_mat
    e.background_mode = Environment.BG_SKY
    e.sky = sky
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color("b9c9bd")
    e.ambient_light_energy = 0.55
    e.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    e.fog_enabled = true
    e.fog_light_color = Color("bfd0c0")
    e.fog_density = 0.0012
    environment_node.environment = e
    add_child(environment_node)

func _create_terrain() -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var cell := WORLD_RADIUS * 2.0 / float(TERRAIN_CELLS)
    for z in range(TERRAIN_CELLS):
        for x in range(TERRAIN_CELLS):
            var x0 := -WORLD_RADIUS + x * cell
            var z0 := -WORLD_RADIUS + z * cell
            var a := Vector3(x0, height_at(x0, z0), z0)
            var b := Vector3(x0 + cell, height_at(x0 + cell, z0), z0)
            var c := Vector3(x0 + cell, height_at(x0 + cell, z0 + cell), z0 + cell)
            var d := Vector3(x0, height_at(x0, z0 + cell), z0 + cell)
            for v in [a,b,c,a,c,d]:
                var hue := _terrain_noise.get_noise_2d(v.x * 2.1, v.z * 2.1)
                var color := Color("4e7451").lerp(Color("6d945c"), clampf(0.48 + hue * 0.37, 0.0, 1.0))
                if v.y > 3.9:
                    color = color.lerp(Color("788477"), clampf((v.y - 3.9) / 5.0, 0.0, 0.6))
                st.set_color(color)
                st.add_vertex(v)
    st.generate_normals()
    var terrain := MeshInstance3D.new()
    terrain.name = "Rolling grassland"
    terrain.mesh = st.commit()
    var m := _mat(Color.WHITE)
    m.vertex_color_use_as_albedo = true
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    terrain.material_override = m
    add_child(terrain)

# Distant scenery skyline uses a shared mesh rather than thousands of objects.
func _create_mountain_silhouette() -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for m in range(21):
        var angle := TAU * float(m) / 21.0
        var center := Vector3(cos(angle)*175.0,0,sin(angle)*175.0)
        var summit_y := _rng.randf_range(31.0,74.0)
        var radius := _rng.randf_range(29.0,58.0)
        var segments := 10
        for k in range(segments):
            var a := TAU * float(k) / segments
            var b := TAU * float(k+1) / segments
            var shape_a := radius * (0.84 + 0.2 * sin(float(k+m)*5.21))
            var shape_b := radius * (0.84 + 0.2 * sin(float(k+1+m)*5.21))
            var v1 := center + Vector3(cos(a)*shape_a, _rng.randf_range(-3.0,1.0), sin(a)*shape_a)
            var v2 := center + Vector3(cos(b)*shape_b, _rng.randf_range(-3.0,1.0), sin(b)*shape_b)
            var summit := center + Vector3(_rng.randf_range(-5.0,5.0),summit_y,_rng.randf_range(-5.0,5.0))
            for v in [v1,v2,summit]:
                var c := Color("77938b") if v.y < 28.0 else Color("859b9e")
                if v.y > 45.0:
                    c = Color("bbc5bb")
                st.set_color(c)
                st.add_vertex(v)
    st.generate_normals()
    var back := MeshInstance3D.new()
    back.name = "Misty alpine skyline"
    back.mesh = st.commit()
    var material := _mat(Color.WHITE)
    material.vertex_color_use_as_albedo = true
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    back.material_override = material
    add_child(back)

func _create_path() -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(110):
        var z0 := -78.0 + float(i) * 1.4
        var z1 := z0 + 1.4
        var x0 := sin(z0 * 0.081) * 5.0
        var x1 := sin(z1 * 0.081) * 5.0
        var width := 2.15
        var corners := [Vector3(x0-width, height_at(x0-width,z0)+0.055,z0),
                        Vector3(x0+width, height_at(x0+width,z0)+0.055,z0),
                        Vector3(x1+width, height_at(x1+width,z1)+0.055,z1),
                        Vector3(x1-width, height_at(x1-width,z1)+0.055,z1)]
        for v in [corners[0], corners[1], corners[2], corners[0], corners[2], corners[3]]:
            st.set_color(Color("967e5f").lerp(Color("c7ae7b"), 0.3 + sin(v.z * 0.41) * 0.1))
            st.add_vertex(v)
    st.generate_normals()
    var path := MeshInstance3D.new()
    path.name = "Old explorer trail"
    path.mesh = st.commit()
    var m := _mat(Color.WHITE)
    m.vertex_color_use_as_albedo = true
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    path.material_override = m
    add_child(path)

func _create_water() -> void:
    var pond := MeshInstance3D.new()
    pond.name = "Moonstone pond"
    var mesh := CylinderMesh.new()
    mesh.top_radius = 10.0
    mesh.bottom_radius = 10.8
    mesh.height = 0.07
    mesh.radial_segments = 48
    pond.mesh = mesh
    pond.position = Vector3(-29, height_at(-29,22)+0.14, 22)
    var m := _mat(Color("71b6ae"), 0.12)
    m.metallic = 0.18
    pond.material_override = m
    add_child(pond)
    for i in range(24):
        var angle := TAU * float(i) / 24.0
        var radius := 10.3 + _rng.randf_range(-0.3, 0.65)
        _spawn_asset(ROCKS[i%ROCKS.size()], Vector3(-29+cos(angle)*radius,height_at(-29+cos(angle)*radius,22+sin(angle)*radius),22+sin(angle)*radius),_rng.randf_range(0.5,1.5))

func _mesh(mesh: Mesh, pos: Vector3, mat: Material, parent: Node3D = self, scale_size: Vector3 = Vector3.ONE) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.material_override = mat
    node.position = pos
    node.scale = scale_size
    parent.add_child(node)
    return node

func _load_asset_scenes() -> void:
    for id in TREE_MODELS + DETAILS + ROCKS:
        var model: PackedScene = load(ASSET_ROOT + id + ".gltf")
        if model != null:
            _asset_scenes[id] = model
        else:
            push_error("Forest model unavailable: " + id)

func _spawn_asset(id: String, where: Vector3, scale_value: float, optional: bool = false) -> Node3D:
    if not _asset_scenes.has(id):
        return null
    var instance: Node3D = (_asset_scenes[id] as PackedScene).instantiate()
    instance.name = id
    instance.position = where
    instance.rotation.y = _rng.randf_range(-PI, PI)
    instance.scale = Vector3.ONE * scale_value
    add_child(instance)
    if id in TREE_MODELS and Vector2(where.x,where.z).length() > 36.0:
        _optional_trees.append(instance)
    if optional:
        _optional_details.append(instance)
        asset_detail_count += 1
    return instance

func apply_detail_quality(high: bool) -> void:
    _low_quality = not high
    # All scenery is deterministic; quality only hides small decorative foliage.
    for i in range(_optional_details.size()):
        _optional_details[i].visible = high or i % 3 == 0
    for i in range(_optional_trees.size()):
        _optional_trees[i].visible = high or i % 4 != 0

func _create_trees() -> void:
    # Keep the playable spawn glade and trail open; foreground forest is now
    # genuine glTF tree meshes with bark textures and alpha-cutout foliage.
    for i in range(105):
        var x := _rng.randf_range(-87.0, 87.0)
        var z := _rng.randf_range(-87.0, 87.0)
        if Vector2(x,z).length() < 11.0 or absf(x-sin(z*0.081)*5.0) < 3.1:
            continue
        if Vector2(x+29,z-22).length() < 13.0:
            continue
        var model: String = TREE_MODELS[i%6]
        if i%19 == 0 and Vector2(x,z).length() > 36.0:
            model = TREE_MODELS[6 + (i%2)]
        var t := _spawn_asset(model, Vector3(x,height_at(x,z),z),_rng.randf_range(0.85,1.28))
        if t != null:
            asset_tree_count += 1
    # Hand-composed forest frame surrounding the first player's viewpoint.
    # Placed outside the spawn clearance; no giant crimson canopy over camera.
    var focal_grove := [[-15.0,7.0],[17.0,9.0],[-13.0,-13.0],[14.0,-12.0],[-20.0,-27.0],[18.0,-26.0],[-11.0,34.0],[14.0,33.0]]
    for i in range(focal_grove.size()):
        var px: float = focal_grove[i][0]
        var pz: float = focal_grove[i][1]
        if _spawn_asset(TREE_MODELS[i%6],Vector3(px,height_at(px,pz),pz),_rng.randf_range(0.9,1.2)) != null:
            asset_tree_count += 1

func _create_rocks_and_flowers() -> void:
    # Low-cost real scene instances: single clumps instead of dozens of
    # primitive cylinders/spheres each requiring a material and draw call.
    for i in range(225):
        var x := _rng.randf_range(-84.0,84.0)
        var z := _rng.randf_range(-84.0,84.0)
        if Vector2(x,z).length() < 7.0:
            continue
        var pos := Vector3(x, height_at(x,z)+0.03,z)
        if i%8 == 0:
            _spawn_asset(ROCKS[i%ROCKS.size()],pos,_rng.randf_range(0.75,1.7))
        else:
            var id: String = DETAILS[i%DETAILS.size()]
            _spawn_asset(id,pos,_rng.randf_range(0.72,1.4),true)
    # Dense waist-height meadow edges rather than isolated decorations.
    for i in range(145):
        var z := _rng.randf_range(-46.0,44.0)
        var side := -1.0 if i%2 == 0 else 1.0
        var x := sin(z*0.081)*5.0 + side*_rng.randf_range(3.4,14.0)
        if Vector2(x,z).length() < 5.0:
            continue
        var m: String = DETAILS[i%DETAILS.size()]
        _spawn_asset(m,Vector3(x,height_at(x,z)+0.02,z),_rng.randf_range(0.7,1.22),true)

func _create_landmark() -> void:
    # A stone waypoint in the starting clearing.
    for i in range(8):
        var angle := float(i) * TAU / 8
        var x := 7.5 + cos(angle)*2.4
        var z := 2.0 + sin(angle)*2.4
        _spawn_asset(ROCKS[i%ROCKS.size()],Vector3(x,height_at(x,z),z),0.65)
    var base := CylinderMesh.new()
    base.top_radius = 0.72
    base.bottom_radius = 0.88
    base.height = 2.8
    base.radial_segments = 7
    _mesh(base,Vector3(7.5,1.4,2),_mat(Color("a5a69b")))
    var crystal := SphereMesh.new()
    crystal.radial_segments = 8
    crystal.rings = 5
    _mesh(crystal,Vector3(7.5,3.25,2),_mat(Color("93e7c9"),0.16),self,Vector3(0.55,0.95,0.55))
    var lamp := OmniLight3D.new()
    lamp.light_color = Color("8adac7")
    lamp.light_energy = 1.6
    lamp.omni_range = 10.0
    lamp.position = Vector3(7.5,3.6,2)
    add_child(lamp)
