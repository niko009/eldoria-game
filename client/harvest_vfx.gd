extends Node3D
# Lightweight, ephemeral visual feedback. Never run on the dedicated server.
const MAX_FALLING_TREES := 3
const MAX_PICKUP_BURSTS := 5
const FALL_SECONDS := 1.25
const MAX_SOUNDS := 6
const WOOD_SFX := preload("res://assets/sfx/wood_chop.wav")
const STONE_SFX := preload("res://assets/sfx/stone_hit.wav")
const HERB_SFX := preload("res://assets/sfx/herb_rustle.wav")
const BUILD_SFX := preload("res://assets/sfx/build_place.wav")
var _falling: Dictionary = {}
var _bursts: Array[Node3D] = []
var _particle_mesh: SphereMesh
var _sounds: Array[AudioStreamPlayer3D] = []
var sound_enabled := true

func _ready() -> void:
    _particle_mesh = SphereMesh.new()
    _particle_mesh.radius = 0.075
    _particle_mesh.height = 0.15
    _particle_mesh.radial_segments = 6
    _particle_mesh.rings = 3

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
    effect.mesh = _particle_mesh
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color("85bb61") if kind == "herb" else (Color("a87848") if kind == "wood" else Color("aeb5a9"))
    effect.material_override = mat
    add_child(effect)
    _bursts.append(effect)
    effect.emitting = true
    play_sound(kind,spot)
    get_tree().create_timer(1.0).timeout.connect(func() -> void:
        _bursts.erase(effect)
        if is_instance_valid(effect):
            effect.queue_free())
    return true

func play_sound(kind: String, world_position: Vector3) -> bool:
    if DisplayServer.get_name() == "headless" or not sound_enabled or _sounds.size() >= MAX_SOUNDS:
        return false
    var stream: AudioStream = null
    match kind:
        "wood": stream = WOOD_SFX
        "stone": stream = STONE_SFX
        "herb": stream = HERB_SFX
        "build": stream = BUILD_SFX
        _: return false
    var audio := AudioStreamPlayer3D.new()
    audio.name = "Sound_" + kind
    audio.stream = stream
    audio.position = world_position
    audio.unit_size = 3.5
    audio.max_distance = 25.0
    audio.volume_db = -8.0
    add_child(audio)
    _sounds.append(audio)
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

func clear_effects() -> void:
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

func active_sound_count() -> int:
    return _sounds.size()

func falling_tree_count() -> int:
    return _falling.size()

func burst_count() -> int:
    return _bursts.size()
