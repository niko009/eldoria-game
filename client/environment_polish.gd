extends Node3D
## Client-only, bounded ambience around nearby campfires. Never saved or
## sent over the network; all world structure remains server authoritative.
const MAX_LIGHTS := 2
const MAX_LIGHT_DISTANCE := 17.0
var high_detail := true
var night := false
var camp_lights: Array[OmniLight3D] = []
var embers: Array[CPUParticles3D] = []
var _flicker_clock := 0.0

func _ready() -> void:
    if DisplayServer.get_name() == "headless":
        return
    var mesh := SphereMesh.new()
    mesh.radius = 0.035
    mesh.height = 0.07
    mesh.radial_segments = 5
    mesh.rings = 3
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color("ffbc72")
    for i in MAX_LIGHTS:
        var lamp := OmniLight3D.new()
        lamp.name = "CampWarmLight%d" % i
        lamp.light_color = Color("ffac63")
        lamp.light_energy = 1.0
        lamp.omni_range = 7.0
        lamp.omni_attenuation = 2.1
        lamp.shadow_enabled = false
        lamp.visible = false
        add_child(lamp)
        camp_lights.append(lamp)
        var particles := CPUParticles3D.new()
        particles.name = "CampEmbers%d" % i
        particles.amount = 8
        particles.lifetime = 0.95
        particles.one_shot = false
        particles.emitting = false
        particles.direction = Vector3.UP
        particles.spread = 25.0
        particles.initial_velocity_min = 0.45
        particles.initial_velocity_max = 1.1
        particles.gravity = Vector3(0,-0.15,0)
        particles.mesh = mesh
        particles.material_override = material
        particles.visible = false
        add_child(particles)
        embers.append(particles)

func set_high_detail(high: bool) -> void:
    high_detail = high
    if not high:
        clear()

func set_night(value: bool) -> void:
    night = value

func update_campfires(buildings: Dictionary, viewer: Vector3) -> void:
    if not high_detail or not viewer.is_finite() or camp_lights.is_empty():
        clear()
        return
    var nearby: Array[Dictionary] = []
    for building in buildings.values():
        if not is_instance_valid(building) or building.kind != "campfire" or building.is_preview:
            continue
        var at: Vector3 = building.position + Vector3.UP*0.68
        var distance_sq: float = Vector2(at.x-viewer.x,at.z-viewer.z).length_squared()
        if distance_sq <= MAX_LIGHT_DISTANCE*MAX_LIGHT_DISTANCE:
            nearby.append({"at":at,"distance":distance_sq})
    nearby.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
        return float(a["distance"]) < float(b["distance"]))
    for i in camp_lights.size():
        var active := i < mini(MAX_LIGHTS,nearby.size())
        camp_lights[i].visible = active
        embers[i].visible = active
        embers[i].emitting = active
        if active:
            camp_lights[i].position = nearby[i]["at"]
            embers[i].position = nearby[i]["at"]
            camp_lights[i].light_energy = 1.05 if night else 0.52

func _process(delta: float) -> void:
    if not high_detail:
        return
    _flicker_clock += delta
    for i in camp_lights.size():
        if camp_lights[i].visible:
            camp_lights[i].light_energy = (1.05 if night else 0.52) * (
                0.92 + 0.07*sin(_flicker_clock*7.2+i*2.1))

func active_light_count() -> int:
    var count := 0
    for lamp in camp_lights:
        if lamp.visible:
            count += 1
    return count

func clear() -> void:
    for light in camp_lights:
        light.visible = false
    for particles in embers:
        particles.emitting = false
        particles.visible = false
