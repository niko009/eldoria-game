extends Node3D
# Lightweight, ephemeral visual feedback. Never run on the dedicated server.
const MAX_FALLING_TREES := 3
const MAX_PICKUP_BURSTS := 5
const MAX_RESOURCE_FEEDBACK := 5
const MAX_BUILD_BURSTS := 4
const MAX_COMBAT_BURSTS := 6
const MAX_ABILITY_BURSTS := 4
const FALL_SECONDS := 1.25
const MAX_SOUNDS := 6
const WOOD_SFX := preload("res://assets/sfx/wood_chop.wav")
const STONE_SFX := preload("res://assets/sfx/stone_hit.wav")
const HERB_SFX := preload("res://assets/sfx/herb_rustle.wav")
const BUILD_SFX := preload("res://assets/sfx/build_place.wav")
const SOUND_CLIPS := {
    "step_a": preload("res://assets/sfx/kenney/step_grass_a.ogg"),
    "step_b": preload("res://assets/sfx/kenney/step_grass_b.ogg"),
    "punch": preload("res://assets/sfx/kenney/punch.ogg"),
    "spear_swing": preload("res://assets/sfx/kenney/spear_swing.ogg"),
    "spear_hit": preload("res://assets/sfx/kenney/spear_hit.ogg"),
    "shield_hit": preload("res://assets/sfx/kenney/hit_shield.ogg"),
    "wolf_hit": preload("res://assets/sfx/kenney/hit_wolf.ogg"),
    "obstacle_hit": preload("res://assets/sfx/kenney/hit_obstacle.ogg"),
    "gear_swish": preload("res://assets/sfx/kenney/gear_swish.ogg"),
    "bow": preload("res://assets/sfx/bow_twang.wav"),
    "wolf_bite": preload("res://assets/sfx/wolf_snarl.wav"),
    "wolf_death": preload("res://assets/sfx/wolf_death.wav"),
    "heal": preload("res://assets/sfx/mage_heal.wav"),
    "dash": preload("res://assets/sfx/rogue_dash.wav"),
    "taunt": preload("res://assets/sfx/knight_taunt.wav")
}
const SOUND_COOLDOWN_MS := {
    "step_a": 280, "step_b": 280, "wolf_bite": 240,
    "wolf_hit": 110, "spear_hit": 100, "shield_hit": 140,
    "punch": 160, "obstacle_hit": 120, "wolf_death": 250
}
var _falling: Dictionary = {}
var _bursts: Array[Node3D] = []
var _resource_feedback: Array[Node3D] = []
var _particle_mesh: SphereMesh
var _pickup_meshes: Dictionary = {}
var _building_bursts: Array[Node3D] = []
var _combat_bursts: Array[Node3D] = []
var _ability_bursts: Array[Node3D] = []
var _combat_high_detail := true
var _sounds: Array[AudioStreamPlayer3D] = []
var _sound_last_played: Dictionary = {}
var sound_enabled := true

func _ready() -> void:
    _particle_mesh = SphereMesh.new()
    _particle_mesh.radius = 0.075
    _particle_mesh.height = 0.15
    _particle_mesh.radial_segments = 6
    _particle_mesh.rings = 3
    var splinter := BoxMesh.new()
    splinter.size = Vector3(0.045, 0.19, 0.06)
    var shard := PrismMesh.new()
    shard.size = Vector3(0.13, 0.11, 0.13)
    var leaf := QuadMesh.new()
    leaf.size = Vector2(0.13, 0.23)
    _pickup_meshes = {"wood": splinter, "stone": shard, "herb": leaf}

func play_tree_fall(resource_id: int, forest: Node3D, actor_pos: Vector3) -> bool:
    if DisplayServer.get_name() == "headless":
        return false
    if _falling.has(resource_id) or _falling.size() >= MAX_FALLING_TREES:
        return false
    var entry: Dictionary = forest.resource_by_id(resource_id)
    if entry.is_empty() or str(entry["kind"]) != "wood" or int(entry["index"]) < 0:
        return false
    var group: String = entry["group"]
    var base: String = group.split("#")[0]
    if not forest._asset_scenes.has(base):
        return false
    var transforms: Array = forest.batch_transforms[group]
    var original: Transform3D = transforms[int(entry["index"])]
    var pivot := Node3D.new()
    pivot.name = "FallingTree_%d" % resource_id
    pivot.position = original.origin
    var model: Node3D = forest._asset_scenes[base].instantiate()
    # Preserve exactly the original asset, uniform scale and yaw of the MultiMesh.
    model.transform = Transform3D(original.basis, Vector3.ZERO)
    pivot.add_child(model)
    add_child(pivot)
    _falling[resource_id] = pivot
    var away := Vector3(original.origin.x-actor_pos.x,0.0,original.origin.z-actor_pos.z)
    if away.length_squared() < 0.03:
        away = Vector3(1.0,0.0,0.0)
    away = away.normalized()
    var axis := Vector3(away.z,0.0,-away.x)
    var tween := create_tween()
    tween.tween_method(func(angle: float) -> void:
        if is_instance_valid(pivot):
            pivot.quaternion = Quaternion(axis,angle),0.0,1.36,FALL_SECONDS).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    tween.tween_callback(func() -> void:
        if is_instance_valid(pivot):
            pivot.queue_free()
        _falling.erase(resource_id))
    return true

func play_pickup(kind: String, spot: Vector3) -> bool:
    if DisplayServer.get_name() == "headless" or _bursts.size() >= MAX_PICKUP_BURSTS:
        return false
    if not kind in ["wood","stone","herb"]:
        return false
    var effect := CPUParticles3D.new()
    effect.name = "Gather_%s" % kind
    effect.position = spot+Vector3(0,0.55,0)
    effect.one_shot = true
    effect.emitting = false
    effect.amount = 9 if kind != "wood" else 13
    effect.lifetime = 0.62
    effect.explosiveness = 1.0
    effect.initial_velocity_min = 0.9
    effect.initial_velocity_max = 2.3
    effect.spread = 65.0
    effect.direction = Vector3.UP
    effect.gravity = Vector3(0,-4.0,0)
    effect.mesh = _pickup_meshes.get(kind, _particle_mesh)
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.albedo_color = Color("85bb61") if kind == "herb" else (Color("a87848") if kind == "wood" else Color("aeb5a9"))
    effect.material_override = mat
    add_child(effect)
    _bursts.append(effect)
    effect.emitting = true
    # Show a short, camera-facing reward marker at the actual resource, never
    # for a rejected harvest. We deliberately omit quantities: the existing
    # gather_effect RPC carries remaining stock, not awarded inventory units.
    _show_resource_feedback(kind, spot)
    play_sound(kind,spot)
    get_tree().create_timer(1.0).timeout.connect(func() -> void:
        _bursts.erase(effect)
        if is_instance_valid(effect):
            effect.queue_free())
    return true

func _show_resource_feedback(kind: String, spot: Vector3) -> void:
    if _resource_feedback.size() >= MAX_RESOURCE_FEEDBACK:
        return
    var popup := Node3D.new()
    popup.name = "GatherFeedback_%s" % kind
    popup.position = spot + Vector3(0, 1.04, 0)
    add_child(popup)
    _resource_feedback.append(popup)
    var label := Label3D.new()
    label.name = "RewardLabel"
    label.text = {"wood": "WOOD", "stone": "STONE", "herb": "HERBS"}[kind]
    label.font_size = 26
    label.pixel_size = 0.007
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.modulate = {"wood": Color("e9bf83"), "stone": Color("d8e0da"),
        "herb": Color("b8e5a2")}[kind]
    label.outline_size = 4
    label.double_sided = true
    label.no_depth_test = false
    popup.add_child(label)
    var tween := create_tween().bind_node(popup)
    tween.set_parallel(true)
    tween.tween_property(popup, "position:y", popup.position.y + 0.58, 0.82).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tween.tween_property(label, "modulate:a", 0.0, 0.82).set_delay(0.15)
    tween.set_parallel(false)
    tween.tween_callback(func() -> void:
        _resource_feedback.erase(popup)
        if is_instance_valid(popup):
            popup.queue_free())

func resource_feedback_count() -> int:
    return _resource_feedback.size()

func play_build_effect(kind: String, spot: Vector3) -> bool:
    # Created only on authoritative building_created events, never on save
    # restoration or when the player moves a red/green placement preview.
    if DisplayServer.get_name() == "headless" or kind not in ["campfire", "tent"]:
        return false
    if _building_bursts.size() >= MAX_BUILD_BURSTS:
        return false
    var effect := Node3D.new()
    effect.name = "BuildBurst_%s" % kind
    effect.position = spot + Vector3(0, 0.07, 0)
    add_child(effect)
    _building_bursts.append(effect)
    # One ephemeral rune ring per building, no permanent particle emitter.
    var ring := MeshInstance3D.new()
    ring.name = "PlacementRipple"
    var shape := TorusMesh.new()
    shape.inner_radius = 0.83 if kind == "campfire" else 1.42
    shape.outer_radius = 0.90 if kind == "campfire" else 1.50
    shape.rings = 4
    shape.ring_segments = 24
    ring.mesh = shape
    var ring_mat := StandardMaterial3D.new()
    ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ring_mat.albedo_color = Color(0.97, 0.80, 0.48, 0.78)
    ring.material_override = ring_mat
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    effect.add_child(ring)
    var dust := CPUParticles3D.new()
    dust.name = "ConstructionDust"
    dust.one_shot = true
    dust.emitting = false
    dust.amount = 12
    dust.lifetime = 0.58
    dust.explosiveness = 1.0
    dust.initial_velocity_min = 0.45
    dust.initial_velocity_max = 1.6
    dust.direction = Vector3.UP
    dust.spread = 70
    dust.gravity = Vector3(0, -3, 0)
    dust.mesh = _particle_mesh
    var dust_mat := StandardMaterial3D.new()
    dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    dust_mat.albedo_color = Color("c6a474") if kind == "tent" else Color("9c9c89")
    dust.material_override = dust_mat
    effect.add_child(dust)
    dust.emitting = true
    var tween := create_tween()
    tween.tween_property(ring, "scale", Vector3(1.20, 1.0, 1.20), 0.52).from(Vector3(0.62, 1.0, 0.62)).set_trans(Tween.TRANS_CUBIC)
    tween.parallel().tween_property(ring_mat, "albedo_color:a", 0.0, 0.52)
    get_tree().create_timer(1.2).timeout.connect(func() -> void:
        _building_bursts.erase(effect)
        if is_instance_valid(effect):
            effect.queue_free())
    return true

func building_burst_count() -> int:
    return _building_bursts.size()

func set_combat_detail(high: bool) -> void:
    _combat_high_detail = high

func combat_burst_count() -> int:
    return _combat_bursts.size()

func ability_burst_count() -> int:
    return _ability_bursts.size()

func play_ability_effect(kind: String, at: Vector3) -> bool:
    if DisplayServer.get_name() == "headless" or not at.is_finite():
        return false
    if kind not in ["heal","dash","taunt"] or _ability_bursts.size() >= MAX_ABILITY_BURSTS:
        return false
    var effect := Node3D.new()
    effect.name = "Ability_%s" % kind
    effect.position = at + Vector3.UP*0.07
    add_child(effect)
    _ability_bursts.append(effect)
    var shade := Color("9df5df") if kind == "heal" else (
        Color("e9c17a") if kind == "taunt" else Color("bbacf8"))
    var ring := MeshInstance3D.new()
    ring.name = "AbilityRing"
    var mesh := TorusMesh.new()
    mesh.inner_radius = 0.55
    mesh.outer_radius = 0.67
    mesh.ring_segments = 24 if _combat_high_detail else 12
    mesh.rings = 4
    ring.mesh = mesh
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_color = Color(shade.r,shade.g,shade.b,0.83)
    ring.material_override = material
    ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    effect.add_child(ring)
    var sparks := CPUParticles3D.new()
    sparks.name = "AbilitySparks"
    sparks.amount = 16 if _combat_high_detail else 5
    sparks.one_shot = true
    sparks.emitting = false
    sparks.lifetime = 0.58
    sparks.explosiveness = 1.0
    sparks.initial_velocity_min = 0.6
    sparks.initial_velocity_max = 1.7
    sparks.spread = 60
    sparks.direction = Vector3.UP
    sparks.gravity = Vector3(0,-1.5,0)
    sparks.mesh = _particle_mesh
    var spark_material := StandardMaterial3D.new()
    spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    spark_material.albedo_color = shade
    sparks.material_override = spark_material
    effect.add_child(sparks)
    sparks.emitting = true
    var tween := create_tween().bind_node(effect)
    tween.set_parallel(true)
    tween.tween_property(ring,"scale",Vector3(2.2,1.0,2.2),0.65).from(Vector3(0.35,1.0,0.35))
    tween.tween_property(material,"albedo_color:a",0.0,0.65)
    tween.set_parallel(false)
    tween.tween_callback(func() -> void:
        _ability_bursts.erase(effect)
        if is_instance_valid(effect):
            effect.queue_free())
    return true

func play_combat_impact(kind: String, at: Vector3, damage: int) -> bool:
    # Server-authoritative hit events only. Keep bursts bounded on Android.
    if DisplayServer.get_name() == "headless" or not at.is_finite():
        return false
    if kind not in ["wolf", "wildlife", "training", "obstacle"] or damage < 0 or damage > 1000:
        return false
    if _combat_bursts.size() >= MAX_COMBAT_BURSTS:
        return false
    var root := Node3D.new()
    root.name = "CombatImpact_%s" % kind
    root.position = at
    add_child(root)
    _combat_bursts.append(root)
    var shade := Color("f8da91") if kind == "obstacle" else (Color("a7ecdc") if kind == "training" else Color("ff9675"))
    var spark := CPUParticles3D.new()
    spark.name = "HitSparks"
    spark.amount = 10 if _combat_high_detail else 4
    spark.one_shot = true
    spark.emitting = false
    spark.lifetime = 0.42
    spark.explosiveness = 1.0
    spark.direction = Vector3.UP
    spark.spread = 85.0
    spark.initial_velocity_min = 0.5
    spark.initial_velocity_max = 2.1
    spark.gravity = Vector3(0.0, -3.4, 0.0)
    spark.mesh = _particle_mesh
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = shade
    spark.material_override = material
    root.add_child(spark)
    spark.emitting = true
    var label := Label3D.new()
    label.name = "DamageNumber"
    label.text = "-%d" % damage if damage > 0 else ("БЛОК" if kind == "obstacle" else "ТРЕНИРОВКА")
    label.modulate = shade
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.outline_size = 5
    label.font_size = 32 if damage > 0 else 24
    label.pixel_size = 0.008
    label.double_sided = true
    label.position.y = 0.18
    root.add_child(label)
    var tween := create_tween().bind_node(root)
    tween.set_parallel(true)
    tween.tween_property(label,"position:y",0.75,0.68).set_trans(Tween.TRANS_CUBIC)
    tween.tween_property(label,"modulate:a",0.0,0.68).set_delay(0.16)
    tween.set_parallel(false)
    tween.tween_callback(func() -> void:
        _combat_bursts.erase(root)
        if is_instance_valid(root):
            root.queue_free())
    return true

func play_sound(kind: String, world_position: Vector3) -> bool:
    if DisplayServer.get_name() == "headless" or not sound_enabled or _sounds.size() >= MAX_SOUNDS or not world_position.is_finite():
        return false
    var stream: AudioStream = SOUND_CLIPS.get(kind)
    match kind:
        "wood": stream = WOOD_SFX
        "stone": stream = STONE_SFX
        "herb": stream = HERB_SFX
        "build": stream = BUILD_SFX
    if stream == null:
        return false
    var now := Time.get_ticks_msec()
    if now-int(_sound_last_played.get(kind,-999999)) < int(SOUND_COOLDOWN_MS.get(kind,90)):
        return false
    var audio := AudioStreamPlayer3D.new()
    audio.name = "Sound_" + kind
    audio.stream = stream
    audio.position = world_position
    audio.unit_size = 3.5
    audio.max_distance = 25.0
    audio.volume_db = -15.0 if kind.begins_with("step") else (-10.0 if kind.begins_with("wolf") else -8.0)
    add_child(audio)
    _sounds.append(audio)
    _sound_last_played[kind] = now
    audio.finished.connect(func() -> void:
        _sounds.erase(audio)
        if is_instance_valid(audio):
            audio.queue_free())
    audio.play()
    return true

func set_sound_enabled(enabled: bool) -> void:
    sound_enabled = enabled
    if not enabled:
        for sound in _sounds:
            if is_instance_valid(sound):
                sound.stop()
                sound.queue_free()
        _sounds.clear()
        _sound_last_played.clear()

func clear_effects() -> void:
    for ability in _ability_bursts:
        if is_instance_valid(ability):
            ability.queue_free()
    _ability_bursts.clear()
    for impact in _combat_bursts:
        if is_instance_valid(impact):
            impact.queue_free()
    _combat_bursts.clear()
    for marker in _resource_feedback:
        if is_instance_valid(marker):
            marker.queue_free()
    _resource_feedback.clear()
    for effect in _building_bursts:
        if is_instance_valid(effect):
            effect.queue_free()
    _building_bursts.clear()
    for pivot in _falling.values():
        if is_instance_valid(pivot):
            pivot.queue_free()
    _falling.clear()
    for burst in _bursts:
        if is_instance_valid(burst):
            burst.queue_free()
    _bursts.clear()
    for sound in _sounds:
        if is_instance_valid(sound):
            sound.stop()
            sound.queue_free()
    _sounds.clear()
    _sound_last_played.clear()

func active_sound_count() -> int:
    return _sounds.size()

func falling_tree_count() -> int:
    return _falling.size()

func burst_count() -> int:
    return _bursts.size()
