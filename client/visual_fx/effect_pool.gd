extends Node3D
## One shared draw call, material and bounded instance buffer for the whole world.
## No collisions, RPCs, gameplay timers, shaders or per-particle nodes.
const HIGH_LIMIT := 96
const LOW_LIMIT := 24
static var high_detail := OS.get_name() != "Android"
static var _instance: WeakRef
var particles: Array[Dictionary] = []
var batch: MultiMeshInstance3D
var emitted := 0

static func shared(context: Node) -> Node3D:
    var pool = _instance.get_ref() if _instance != null else null
    if not is_instance_valid(pool):
        pool = load("res://visual_fx/effect_pool.gd").new()
        pool.name = "PresentationEffects"
        _instance = weakref(pool)
        context.get_tree().root.add_child.call_deferred(pool)
    return pool

func _ready() -> void:
    if OS.get_cmdline_user_args().has("--dedicated-server"):
        set_process(false)
        return
    batch = MultiMeshInstance3D.new()
    batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var mesh := SphereMesh.new()
    mesh.radius = 0.5
    mesh.height = 1.0
    mesh.radial_segments = 6
    mesh.rings = 3
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.vertex_color_use_as_albedo = true
    mesh.material = material
    batch.multimesh = MultiMesh.new()
    batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
    batch.multimesh.use_colors = true
    batch.multimesh.mesh = mesh
    batch.multimesh.instance_count = HIGH_LIMIT
    batch.multimesh.visible_instance_count = 0
    add_child(batch)

func limit() -> int:
    return HIGH_LIMIT if high_detail else LOW_LIMIT

func burst(kind: String, at: Vector3, forward: Vector3 = Vector3.FORWARD) -> void:
    if OS.get_cmdline_user_args().has("--dedicated-server") or not at.is_finite() or not forward.is_finite():
        return
    var count := 12 if high_detail else 4
    var color := Color("e8b66f")
    var duration := 0.55
    match kind:
        "spell": color = Color("76cfff")
        "heal": color = Color("74efad"); duration = 0.85
        "dash": color = Color("b89aff")
        "taunt": color = Color("ffcf69"); duration = 0.65
        "hit": color = Color("ffb080"); count = 7 if high_detail else 3
        "dust": color = Color("a99c7f"); count = 3 if high_detail else 1
        "harvest": color = Color("c1d989"); count = 8 if high_detail else 3
        "arrow": count = 1; color = Color("ede0b9"); duration = 0.30
        _: return
    for i in count:
        if particles.size() >= limit():
            break
        var angle := TAU * float(i) / float(count)
        var radial := Vector3(cos(angle), 0, sin(angle))
        var velocity := radial * 1.8 + Vector3.UP * 1.1
        var point := at
        var size := Vector3.ONE * 0.10
        var gravity := 3.0
        if kind == "heal":
            point += radial * 0.65
            velocity = Vector3.UP * 1.2
            gravity = 0.0
        elif kind == "spell":
            velocity = forward.normalized() * 4.0 + radial * 0.65
            gravity = 0.0
        elif kind == "dash":
            point += forward * (-float(i) * 0.09)
            velocity = radial * 0.4
            gravity = 0.0
        elif kind == "taunt":
            point += radial * 0.4
            velocity = radial * 2.5
            gravity = 0.0
        elif kind == "dust":
            size = Vector3(0.16, 0.025, 0.24)
            velocity *= 0.08
            gravity = 0.0
        elif kind == "arrow":
            velocity = forward.normalized() * 18.0
            size = Vector3(0.025, 0.025, 0.75)
            gravity = 0.0
        particles.append({"at": point, "velocity": velocity, "age": 0.0,
            "life": duration, "color": color, "size": size, "gravity": gravity,
            "arrow": kind == "arrow"})
        emitted += 1

func _process(delta: float) -> void:
    var corpse_count := 0
    for child in get_children():
        if child == batch or child.is_queued_for_deletion():
            continue
        corpse_count += 1
        if corpse_count > (4 if high_detail else 2):
            child.queue_free()
    while particles.size() > limit():
        particles.pop_back()
    for i in range(particles.size() - 1, -1, -1):
        var p: Dictionary = particles[i]
        p.age += delta
        if p.age >= p.life:
            particles.remove_at(i)
            continue
        p.velocity.y -= p.gravity * delta
        p.at += p.velocity * delta
    if batch == null:
        return
    batch.multimesh.visible_instance_count = particles.size()
    for i in particles.size():
        var p: Dictionary = particles[i]
        var basis := Basis.IDENTITY
        if p.arrow:
            basis = Basis.looking_at(-p.velocity.normalized())
        var shrink := 1.0 if p.arrow else maxf(0.05, 1.0 - p.age / p.life)
        batch.multimesh.set_instance_transform(i, Transform3D(basis.scaled(p.size * shrink), p.at))
        batch.multimesh.set_instance_color(i, p.color)

func clear() -> void:
    particles.clear()
    if batch != null:
        batch.multimesh.visible_instance_count = 0
