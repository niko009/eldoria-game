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
var batch_transforms: Dictionary = {}
var batch_nodes: Array[MultiMeshInstance3D] = []
var obstacle_positions: Array[Vector2] = []
var obstacle_radii: Array[float] = []
var obstacle_active: Array[bool] = []
const TREE_DAMAGE := preload("res://tree_damage.gd")
var damage_markers: Dictionary = {}
var _resource_exhausted := {}
var _grass_candidates: Array[Dictionary] = []
var _grass_cover: Array[Dictionary] = []
var _vegetation_hidden_counts := {}
var _resource_cover_cache := {}
var _instance_resource_ids := {}
var resources: Array[Dictionary] = []
var _batch_nodes_by_key := {}
var _batch_original_transforms := {}
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
    # Append grass resources AFTER all legacy resources to retain PostgreSQL IDs.
    _append_grass_resources()
    _flush_batches()
    _create_visual_accents()

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
    sun.rotation_degrees = Vector3(-43, -34, 0)
    sun.light_color = Color("ffe7bd")
    sun.light_energy = 0.82
    sun.shadow_enabled = true
    add_child(sun)
    environment_node = WorldEnvironment.new()
    var e := Environment.new()
    var sky := Sky.new()
    var sky_mat := ProceduralSkyMaterial.new()
    sky_mat.sky_top_color = Color("668fbd")
    sky_mat.sky_horizon_color = Color("cadde0")
    sky_mat.ground_bottom_color = Color("526e72")
    sky_mat.ground_horizon_color = Color("a8bec0")
    sky_mat.sun_angle_max = 10.0
    sky.sky_material = sky_mat
    e.background_mode = Environment.BG_SKY
    e.sky = sky
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color("a9bfd0")
    e.ambient_light_energy = 0.48
    e.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    e.fog_enabled = true
    e.fog_light_color = Color("b5c9cf")
    e.fog_density = 0.0016
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
                var color := Color("506e56").lerp(Color("8ca46b"), clampf(0.48 + hue * 0.37, 0.0, 1.0))
                if v.y > 3.9:
                    color = color.lerp(Color("89958a"), clampf((v.y - 3.9) / 5.0, 0.0, 0.6))
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
        var summit_y := lerpf(24.0, 47.0, (_rng.randf_range(31.0,74.0) - 31.0) / 43.0)
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
                var c := Color("617d83") if v.y < 23.0 else Color("82999c")
                if v.y > 38.0:
                    c = Color("a9b9b9")
                st.set_color(c)
                st.add_vertex(v)
    st.generate_normals()
    var back := MeshInstance3D.new()
    back.name = "Misty alpine skyline"
    back.mesh = st.commit()
    var material := _mat(Color.WHITE)
    material.vertex_color_use_as_albedo = true
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
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
    # Opaque vertex-coloured water keeps GL Compatibility and Android Low cheap.
    # The shoreline is irregular but uses no gameplay RNG calls.
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    var rings := [0.0, 4.2, 8.3, 10.0]
    var colors := [Color("5d9fa7"), Color("70b6bd"), Color("80c8c2"), Color("9ac7b0")]
    for ring in range(3):
        for i in range(64):
            var a := TAU * float(i) / 64.0
            var b := TAU * float(i + 1) / 64.0
            var wobble_a := 1.0 + 0.065 * sin(a * 5.0 + 0.3) + 0.035 * sin(a * 9.0)
            var wobble_b := 1.0 + 0.065 * sin(b * 5.0 + 0.3) + 0.035 * sin(b * 9.0)
            var inner_a := Vector3(cos(a) * rings[ring] * wobble_a, 0, sin(a) * rings[ring] * wobble_a)
            var outer_a := Vector3(cos(a) * rings[ring + 1] * wobble_a, 0, sin(a) * rings[ring + 1] * wobble_a)
            var inner_b := Vector3(cos(b) * rings[ring] * wobble_b, 0, sin(b) * rings[ring] * wobble_b)
            var outer_b := Vector3(cos(b) * rings[ring + 1] * wobble_b, 0, sin(b) * rings[ring + 1] * wobble_b)
            for vertex in [[inner_a, colors[ring]], [outer_a, colors[ring + 1]], [outer_b, colors[ring + 1]],
                    [inner_a, colors[ring]], [outer_b, colors[ring + 1]], [inner_b, colors[ring]]]:
                surface.set_color(vertex[1])
                surface.add_vertex(vertex[0])
    surface.generate_normals()
    pond.mesh = surface.commit()
    pond.position = Vector3(-29, height_at(-29,22)-1.25, 22)
    var m := _mat(Color.WHITE, 0.42)
    m.vertex_color_use_as_albedo = true
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    m.metallic = 0.06
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    pond.material_override = m
    add_child(pond)
    for i in range(24):
        var angle := TAU * float(i) / 24.0
        var radius := 10.3 + _rng.randf_range(-0.3, 0.65)
        _spawn_asset(ROCKS[i%ROCKS.size()], Vector3(-29+cos(angle)*radius,height_at(-29+cos(angle)*radius,22+sin(angle)*radius),22+sin(angle)*radius),_rng.randf_range(0.5,1.5))

func _create_visual_accents() -> void:
    # This pass runs after every resource ID and batch has been finalized.
    # Small ground colour patches add depth without new collision or loot.
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for patch in range(28):
        var angle := TAU * float(patch) / 28.0
        var center := Vector2(-29.0, 22.0) + Vector2(cos(angle), sin(angle)) * (11.1 + 0.7 * sin(angle * 7.0))
        var radius := 0.65 + 0.22 * sin(angle * 11.0)
        for point in range(6):
            var a := TAU * float(point) / 6.0
            var b := TAU * float(point + 1) / 6.0
            for flat in [center, center + Vector2(cos(a), sin(a)) * radius, center + Vector2(cos(b), sin(b)) * radius]:
                st.set_color(Color("b0ae81") if patch % 3 == 0 else Color("768f6c"))
                st.add_vertex(Vector3(flat.x, height_at(flat.x, flat.y) + 0.065, flat.y))
    st.generate_normals()
    var shore := MeshInstance3D.new()
    shore.name = "Shore colour accents"
    shore.mesh = st.commit()
    var shore_material := _mat(Color.WHITE)
    shore_material.vertex_color_use_as_albedo = true
    shore_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    shore.material_override = shore_material
    add_child(shore)

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

func _spawn_asset(id: String, where: Vector3, scale_value: float, optional: bool = false) -> bool:
    if not _asset_scenes.has(id):
        return false
    var angle := _rng.randf_range(-PI, PI)
    # Keep obstructing trees visible on every platform: no invisible colliders.
    # Only optional flowers/ground foliage may disappear in low quality.
    var group := id + ("#extra" if optional and asset_detail_count % 3 != 0 else "#core")
    if not batch_transforms.has(group):
        batch_transforms[group] = []
    var xform := Transform3D(Basis(Vector3.UP, angle).scaled(Vector3.ONE * scale_value), where)
    batch_transforms[group].append(xform)
    var instance_index: int = batch_transforms[group].size()-1
    if id in ["Grass_Common_Short","Grass_Wispy_Tall"]:
        _grass_candidates.append({"pos":where,"group":group,"index":instance_index})
    if id in ["Grass_Common_Short","Grass_Wispy_Tall","Fern_1","Bush_Common"]:
        _grass_cover.append({"pos":where,"group":group,"index":instance_index})
    if id in TREE_MODELS:
        var obstacle_id := _add_obstacle(Vector2(where.x, where.z), (0.70 if id.begins_with("Twisted") else 0.57) * scale_value)
        _record_resource("wood", where, 4, group, instance_index, obstacle_id)
    elif id in ROCKS:
        _add_obstacle(Vector2(where.x, where.z), 1.06 * scale_value)
        _record_resource("stone", where, 3)
    elif id in ["Flower_3_Group", "Bush_Common_Flowers", "Mushroom_Common"]:
        _record_resource("herb", where, 1, group, instance_index)
    if optional:
        asset_detail_count += 1
    return true

func _append_grass_resources() -> void:
    # This is strictly appended, never inserted between old trees/rocks/herbs.
    for grass in _grass_candidates:
        # Optional detail batches are hidden on Android Low graphics.
        # Do not turn invisible low-quality ground cover into gatherable loot.
        if str(grass["group"]).ends_with("#extra"):
            continue
        _record_resource("herb", grass["pos"], 1, grass["group"], grass["index"])

func _record_resource(kind: String, where: Vector3, amount: int,
        group: String = "", index: int = -1, obstacle_id: int = -1) -> void:
    var new_id := resources.size()+1
    resources.append({"id":new_id,"kind":kind,"pos":where,
        "amount":amount,"group":group,"index":index,"obstacle_id":obstacle_id})
    if index >= 0:
        _instance_resource_ids[group+":"+str(index)] = new_id

func set_resource_quantity(resource_id: int, amount: int) -> void:
    var entry := resource_by_id(resource_id)
    if entry.is_empty():
        return
    if entry["kind"] == "wood":
        _update_tree_damage(resource_id,entry,amount)
    var depleted := amount <= 0
    var before := bool(_resource_exhausted.get(resource_id,false))
    if before == depleted:
        return
    _resource_exhausted[resource_id] = depleted
    if entry["kind"] in ["wood","herb"]:
        if int(entry["index"]) >= 0:
            _set_batch_instance(str(entry["group"]),int(entry["index"]),not depleted)
        if entry["kind"] == "wood" and int(entry["obstacle_id"]) >= 0:
            obstacle_active[int(entry["obstacle_id"])] = not depleted
        # Chopped trees clear nearby grass/ferns and picked herbs clear their patch.
        # Counters prevent re-showing vegetation still hidden by another source.
        var targets: Array = _nearby_vegetation(resource_id,entry)
        for cover in targets:
            var key: String = str(cover["group"]) + ":" + str(cover["index"])
            var n := maxi(0,int(_vegetation_hidden_counts.get(key,0)) + (1 if depleted else -1))
            _vegetation_hidden_counts[key] = n
            _set_batch_instance(str(cover["group"]),int(cover["index"]),n == 0)

func _update_tree_damage(resource_id: int, entry: Dictionary, remaining: int) -> void:
    if DisplayServer.get_name() == "headless" or int(entry["index"]) < 0:
        return
    var hits := clampi(int(entry["amount"])-remaining,0,3)
    if remaining <= 0 or hits == 0:
        if damage_markers.has(resource_id):
            var existing: Node3D = damage_markers[resource_id]
            existing.queue_free()
            damage_markers.erase(resource_id)
        return
    var marks: Node3D = damage_markers.get(resource_id,null)
    if marks == null:
        var original: Transform3D = batch_transforms[entry["group"]][int(entry["index"])]
        marks = TREE_DAMAGE.new()
        marks.name = "TreeDamage_%d" % resource_id
        marks.position = original.origin
        marks.configure(original.basis.get_scale().x,remaining)
        add_child(marks)
        damage_markers[resource_id] = marks
    else:
        marks.update_hits(hits)

func _nearby_vegetation(resource_id: int, entry: Dictionary) -> Array:
    if _resource_cover_cache.has(resource_id):
        return _resource_cover_cache[resource_id]
    var out: Array = []
    var p: Vector3 = entry["pos"]
    var r := 2.7 if entry["kind"] == "wood" else 0.75
    for cover in _grass_cover:
        var spot: Vector3 = cover["pos"]
        if Vector2(p.x,p.z).distance_squared_to(Vector2(spot.x,spot.z)) <= r*r:
            # Gatherable plants must stay visible until their own resource is
            # consumed. Otherwise the world can show invisible loot markers.
            var cover_key := str(cover["group"]) + ":" + str(cover["index"])
            if _instance_resource_ids.has(cover_key):
                continue
            out.append(cover)
    _resource_cover_cache[resource_id] = out
    return out

func _set_batch_instance(group: String, index: int, visible: bool) -> void:
    if not _batch_nodes_by_key.has(group):
        return
    var batch: MultiMeshInstance3D = _batch_nodes_by_key[group]
    var original: Transform3D = _batch_original_transforms[group][index]
    var key := group+":"+str(index)
    if bool(_resource_exhausted.get(int(_instance_resource_ids.get(key,-1)),false)):
        visible = false
    if int(_vegetation_hidden_counts.get(key,0)) > 0:
        visible = false
    batch.multimesh.set_instance_transform(index,original if visible else
        Transform3D(Basis().scaled(Vector3.ZERO),original.origin))

func resource_by_id(resource_id: int) -> Dictionary:
    if resource_id < 1 or resource_id > resources.size():
        return {}
    return resources[resource_id-1]

func nearest_resource(position: Vector3, radius: float, remaining: Dictionary) -> int:
    var best_id := -1
    var best_distance := radius * radius
    var from2 := Vector2(position.x,position.z)
    for resource in resources:
        var id: int = resource["id"]
        if int(remaining.get(id,0)) <= 0:
            continue
        var pos: Vector3 = resource["pos"]
        var distance := from2.distance_squared_to(Vector2(pos.x,pos.z))
        if distance < best_distance and absf(position.y-pos.y) < 5.0:
            best_distance = distance
            best_id = id
    return best_id

func _add_obstacle(pos: Vector2, radius: float) -> int:
    obstacle_positions.append(pos)
    obstacle_radii.append(radius)
    obstacle_active.append(true)
    return obstacle_positions.size()-1

func _flush_batches() -> void:
    # A single MultiMesh draw per imported glTF mesh, not ~350 scene instances.
    for key in batch_transforms.keys():
        var id: String = String(key).split("#")[0]
        var packed: PackedScene = _asset_scenes[id]
        var root_node: Node3D = packed.instantiate()
        var mesh_node := root_node.get_child(0) as MeshInstance3D
        if mesh_node == null or mesh_node.mesh == null:
            push_error("No mesh for nature asset " + id)
            root_node.free()
            continue
        var transforms: Array = batch_transforms[key]
        var multimesh := MultiMesh.new()
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multimesh.mesh = mesh_node.mesh
        multimesh.instance_count = transforms.size()
        var originals: Array[Transform3D] = []
        for i in range(transforms.size()):
            var original_transform: Transform3D = transforms[i] * mesh_node.transform
            multimesh.set_instance_transform(i, original_transform)
            originals.append(original_transform)
        _batch_original_transforms[key] = originals
        var draw := MultiMeshInstance3D.new()
        draw.name = "Batch_" + String(key).replace("#","_")
        draw.multimesh = multimesh
        draw.visible = not String(key).ends_with("#extra") or not _low_quality
        if id in DETAILS:
            draw.visibility_range_end = 90.0
        else:
            draw.visibility_range_end = 155.0
        add_child(draw)
        batch_nodes.append(draw)
        _batch_nodes_by_key[key] = draw
        root_node.free()

func apply_detail_quality(high: bool) -> void:
    _low_quality = not high
    for node in batch_nodes:
        node.visible = high or not node.name.ends_with("_extra")

func collides_at(pos: Vector2, radius: float = 0.43) -> bool:
    for i in range(obstacle_positions.size()):
        if not obstacle_active[i]:
            continue
        var r: float = obstacle_radii[i] + radius
        if pos.distance_squared_to(obstacle_positions[i]) < r*r:
            return true
    return false

func _sweep_hits(start: Vector2, finish: Vector2, radius: float) -> bool:
    var segment := finish-start
    var squared := segment.length_squared()
    if squared < 0.0000001:
        return collides_at(finish, radius)
    for i in range(obstacle_positions.size()):
        if not obstacle_active[i]:
            continue
        var center := obstacle_positions[i]
        var range_radius: float = obstacle_radii[i] + radius
        var begin_dist := start.distance_squared_to(center)
        var end_dist := finish.distance_squared_to(center)
        # Emergency escape from a colliding spawn/reconnect is always permitted.
        if begin_dist < range_radius * range_radius and end_dist > begin_dist:
            continue
        var t := clampf((center-start).dot(segment) / squared,0.0,1.0)
        if (start+segment*t).distance_squared_to(center) < range_radius*range_radius:
            return true
    return false

func move_actor(current: Vector3, direction: Vector3, radius: float = 0.43) -> Vector3:
    var flat := Vector2(current.x, current.z)
    var components := [Vector2(direction.x, 0.0), Vector2(0.0, direction.z)]
    for step in components:
        if step.length_squared() < 0.0000001:
            continue
        if not _sweep_hits(flat, flat + step, radius):
            flat += step
        else:
            var safe := 0.0
            var unsafe := 1.0
            for i in range(9):
                var midpoint := (safe + unsafe) * 0.5
                if _sweep_hits(flat, flat + step*midpoint, radius):
                    unsafe = midpoint
                else:
                    safe = midpoint
            flat += step*safe
    return Vector3(flat.x, height_at(flat.x,flat.y)+1.0, flat.y)

func valid_remote_step(current: Vector3, requested: Vector3, radius: float = 0.43, allowed_jump_height: float = 0.0) -> bool:
    if current.distance_to(requested) > 4.0:
        return false
    var safe := move_actor(current, requested-current, radius)
    return Vector2(safe.x,safe.z).distance_to(Vector2(requested.x,requested.z)) < 0.08 and absf((requested.y-safe.y)-allowed_jump_height) < (0.7 if allowed_jump_height > 0.001 else 0.17)

func _create_trees() -> void:
    # Keep the playable spawn glade and trail open; foreground forest is now
    # genuine glTF tree meshes with bark textures and alpha-cutout foliage.
    for i in range(105):
        var x := _rng.randf_range(-87.0, 87.0)
        var z := _rng.randf_range(-87.0, 87.0)
        if Vector2(x,z).length() < 11.0 or absf(x-sin(z*0.081)*5.0) < 3.1:
            continue
        # Keep the third-person camera corridor clear near the spawn.
        if absf(x) < 7.5 and z > 3.0 and z < 28.0:
            continue
        if Vector2(x+29,z-22).length() < 13.0:
            continue
        var model: String = TREE_MODELS[i%6]
        if i%19 == 0 and Vector2(x,z).length() > 36.0:
            model = TREE_MODELS[6 + (i%2)]
        var t := _spawn_asset(model, Vector3(x,height_at(x,z),z),_rng.randf_range(0.85,1.28))
        if t:
            asset_tree_count += 1
    # Hand-composed forest frame surrounding the first player's viewpoint.
    # Placed outside the spawn clearance; no giant crimson canopy over camera.
    var focal_grove := [[-15.0,7.0],[17.0,9.0],[-13.0,-13.0],[14.0,-12.0],[-20.0,-27.0],[18.0,-26.0],[-11.0,34.0],[14.0,33.0]]
    for i in range(focal_grove.size()):
        var px: float = focal_grove[i][0]
        var pz: float = focal_grove[i][1]
        if _spawn_asset(TREE_MODELS[i%6],Vector3(px,height_at(px,pz),pz),_rng.randf_range(0.9,1.2)) :
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
    # Readily accessible starter herbs make gathering discoverable on spawn.
    for pos2 in [Vector2(-1.8,1.5),Vector2(1.8,-1.5),Vector2(4.5,1.9)]:
        _spawn_asset("Flower_3_Group",Vector3(pos2.x,height_at(pos2.x,pos2.y),pos2.y),1.0,true)

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

# Keep the chase camera in front of solid trunks, boulders and the terrain.
# This is a deterministic approximation; foliage itself is not a solid object.
func camera_safe_target(focus: Vector3, requested: Vector3) -> Vector3:
    var path := requested - focus
    var desired_length := path.length()
    if desired_length < 0.01:
        return requested
    var limit_t := 1.0
    var segment2 := Vector2(path.x, path.z)
    var flat_squared := segment2.length_squared()
    if flat_squared > 0.0001:
        var start2 := Vector2(focus.x,focus.z)
        for i in range(obstacle_positions.size()):
            if not obstacle_active[i]:
                continue
            var radius: float = obstacle_radii[i] + 0.35
            var offset: Vector2 = obstacle_positions[i] - start2
            var dot_t := clampf(offset.dot(segment2) / flat_squared,0.0,1.0)
            if (start2+segment2*dot_t).distance_squared_to(obstacle_positions[i]) > radius*radius:
                continue
            var obstacle_height := 4.0 if obstacle_radii[i] > 1.2 else 12.0
            var line_height := focus.y + path.y * dot_t
            var base_height := height_at(obstacle_positions[i].x, obstacle_positions[i].y)
            if line_height < base_height - 0.5 or line_height > base_height + obstacle_height:
                continue
            # Binary search for the first intersection with an obstacle circle.
            var safe_t := 0.0
            var unsafe_t := dot_t
            for j in range(11):
                var middle := (safe_t + unsafe_t)*0.5
                if (start2+segment2*middle).distance_squared_to(obstacle_positions[i]) < radius*radius:
                    unsafe_t = middle
                else:
                    safe_t = middle
            limit_t = minf(limit_t, maxf(0.12,safe_t-0.02))
    # Even without trees, the line may cut through sloped ground.
    for sample in range(1,37):
        var t := float(sample)/36.0
        if t >= limit_t:
            break
        var at := focus + path*t
        if at.y < height_at(at.x,at.z)+0.35:
            limit_t = maxf(0.12,t-0.035)
            break
    return focus + path*limit_t
