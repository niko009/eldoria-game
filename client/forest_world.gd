extends Node3D
# Original deterministic stylized forest, no downloaded meshes or textures.
# Identical vegetation positions on Windows and Android; visual quality differs.
const WORLD_RADIUS := 94.0
const TERRAIN_CELLS := 88
const TREE_SEED := 20261101
var tree_leaf_meshes: Array[SphereMesh] = []
var leaf_instances: Array[MeshInstance3D] = []
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
    _create_sky()
    _create_terrain()
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
    sun.light_color = Color("ffe4bd")
    sun.light_energy = 0.78
    sun.shadow_enabled = true
    add_child(sun)
    environment_node = WorldEnvironment.new()
    var e := Environment.new()
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color("446c88")
    sky_mat.sky_horizon_color = Color("a6c7bc")
    sky_mat.ground_bottom_color = Color("546a5c")
    sky_mat.ground_horizon_color = Color("acbead")
    sky_mat.sun_angle_max = 10.0
    sky.sky_material = sky_mat
    e.background_mode = Environment.BG_SKY
    e.sky = sky
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color("8fa9ad")
    e.ambient_light_energy = 0.30
    e.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    e.fog_enabled = true
    e.fog_light_color = Color("9bbaa9")
    e.fog_density = 0.004
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
        _rock(Vector3(-29 + cos(angle)*radius, height_at(-29+cos(angle)*radius,22+sin(angle)*radius),22+sin(angle)*radius), _rng.randf_range(0.4,1.25))

func _mesh(mesh: Mesh, pos: Vector3, mat: Material, parent: Node3D = self, scale_size: Vector3 = Vector3.ONE) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.material_override = mat
    node.position = pos
    node.scale = scale_size
    parent.add_child(node)
    return node

func _make_tree(pos: Vector3, which: int, size: float) -> void:
    var root := Node3D.new()
    root.position = pos
    root.rotation.y = _rng.randf_range(0, TAU)
    root.scale = Vector3.ONE * size
    add_child(root)
    var trunk := CylinderMesh.new()
    trunk.height = 5.7 if which != 1 else 8.0
    trunk.top_radius = 0.20 if which != 1 else 0.10
    trunk.bottom_radius = 0.43 if which != 1 else 0.32
    trunk.radial_segments = 8
    var bark := _mat(Color("7b5b46") if which != 2 else Color("d8d1b2"))
    _mesh(trunk, Vector3(0,trunk.height/2.0,0), bark, root)
    if which == 1:
        # Several layered pine skirts, silhouette much richer than a sphere.
        for i in range(4):
            var crown := CylinderMesh.new()
            crown.top_radius = 0.0
            crown.bottom_radius = 2.65 - i*0.39
            crown.height = 3.55
            crown.radial_segments = 9
            var color := Color("315749").lerp(Color("6f9771"), 0.15 + i*0.12)
            _mesh(crown, Vector3(0, 4.7+i*1.05,0), _mat(color), root)
    else:
        var palette := [Color("446c4f"),Color("668d5b"),Color("789d6b"),Color("c6ab62"),Color("96b789")]
        var selected: Color = palette[_rng.randi_range(0,palette.size()-1)]
        for i in range(6):
            var angle := TAU * float(i) / 5.0 + 0.3
            var offset := Vector3(cos(angle)*1.5, 5.4+sin(i*4.4)*0.8, sin(angle)*1.6)
            if i == 5:
                offset = Vector3(0,7.25,0)
            var leaves := SphereMesh.new()
            leaves.radius = 1.0
            leaves.height = 2.0
            leaves.radial_segments = 16
            leaves.rings = 8
            tree_leaf_meshes.append(leaves)
            var leaf_color: Color = selected.lerp(Color("bad09c"), _rng.randf_range(0,0.25))
            var part := _mesh(leaves, offset, _mat(leaf_color), root, Vector3(_rng.randf_range(1.25,2.05),_rng.randf_range(1.1,1.85),_rng.randf_range(1.2,1.8)))
            leaf_instances.append(part)
        for j in range(3):
            var branch := CylinderMesh.new()
            branch.height = 2.5
            branch.top_radius = 0.10
            branch.bottom_radius = 0.22
            branch.radial_segments = 6
            var node := _mesh(branch, Vector3(cos(j*2.1)*0.8,4.7,sin(j*2.1)*0.8),bark,root)
            node.rotation.z = 0.6
            node.rotation.y = j*2.1

func _create_trees() -> void:
    # Open spawn clearing and winding path remain navigable.
    for i in range(110):
        var x := _rng.randf_range(-86.0,86.0)
        var z := _rng.randf_range(-86.0,86.0)
        if Vector2(x,z).length() < 15.0 or absf(x - sin(z*0.081)*5.0) < 4.1:
            continue
        if Vector2(x+29,z-22).length() < 12.5:
            continue
        _make_tree(Vector3(x,height_at(x,z),z),i%3,_rng.randf_range(0.75,1.3))

func _rock(pos: Vector3, size: float) -> void:
    var rock := SphereMesh.new()
    rock.radial_segments = 8
    rock.rings = 5
    var c := Color("8e9a8c").lerp(Color("a8a897"),_rng.randf())
    var mesh := _mesh(rock, pos+Vector3(0,size*0.27,0),_mat(c),self, Vector3(size, size*_rng.randf_range(0.55,0.9),size*_rng.randf_range(0.7,1.35)))
    mesh.rotation.y = _rng.randf_range(0,TAU)

func _create_rocks_and_flowers() -> void:
    for i in range(105):
        var x := _rng.randf_range(-78,78)
        var z := _rng.randf_range(-78,78)
        if Vector2(x,z).length() < 6.0:
            continue
        if i%4 == 0:
            _rock(Vector3(x,height_at(x,z),z),_rng.randf_range(0.32,1.6))
        else:
            var flower_stem := CylinderMesh.new()
            flower_stem.height = 0.55
            flower_stem.top_radius = 0.028
            flower_stem.bottom_radius = 0.04
            flower_stem.radial_segments = 5
            var flower := SphereMesh.new()
            flower.radial_segments = 7
            flower.rings = 4
            var stem_pos := Vector3(x,height_at(x,z),z)
            _mesh(flower_stem,stem_pos+Vector3(0,0.275,0),_mat(Color("5e8152")))
            var bloom_col: Color = [Color("f4cf72"),Color("e9b5bd"),Color("d9c8e6"),Color("fff3cf")][i%4]
            _mesh(flower,stem_pos+Vector3(0,0.62,0),_mat(bloom_col),self,Vector3(0.17,0.12,0.17))

func _create_landmark() -> void:
    # A stone waypoint in the starting clearing.
    for i in range(8):
        var angle := float(i) * TAU / 8
        var x := 7.5 + cos(angle)*2.4
        var z := 2.0 + sin(angle)*2.4
        _rock(Vector3(x,height_at(x,z),z),0.8)
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
