extends Node3D
## Local hand-space bow string. Its tween never changes the actor or server state.
const FX := preload("res://visual_fx/effect_pool.gd")
var strings: Array[MeshInstance3D] = []
var draw_amount := 0.0:
    set(value):
        draw_amount = value
        _pose_string()
var cycle: Tween
var actor: Node3D

func _process(_delta: float) -> void:
    if is_instance_valid(actor):
        # KayKit's ranged clip was authored for a crossbow. Keep the bow limb
        # vertical at its left-hand socket, with the nock drawn toward the hero.
        get_parent().global_basis = Basis(actor.global_basis.z, actor.global_basis.y, -actor.global_basis.x)

func setup(owner_actor: Node3D, original: MeshInstance3D) -> void:
    actor = owner_actor
    original.visible = false
    for i in 2:
        var line := MeshInstance3D.new()
        var mesh := CylinderMesh.new()
        mesh.top_radius = 0.008
        mesh.bottom_radius = 0.008
        mesh.height = 1.0
        mesh.radial_segments = 6
        line.mesh = mesh
        line.material_override = original.material_override
        add_child(line)
        strings.append(line)
    _pose_string()

func _pose_string() -> void:
    for i in strings.size():
        var tip := Vector3(0.12, -0.82 if i == 0 else 0.82, 0)
        var nock := Vector3(0.12 - draw_amount * 0.32, 0, 0)
        var direction := nock - tip
        strings[i].position = (tip + nock) * 0.5
        strings[i].quaternion = Quaternion(Vector3.UP, direction.normalized())
        strings[i].scale.y = direction.length()

func draw() -> void:
    if cycle != null:
        cycle.kill()
    cycle = create_tween()
    cycle.tween_property(self, "draw_amount", 1.0, 0.16)

func shoot() -> void:
    draw()
    cycle.tween_callback(_release)
    cycle.tween_property(self, "draw_amount", 0.0, 0.08)

func _release() -> void:
    if not is_instance_valid(actor) or not actor.preview_projectiles or actor.visual_dead or not actor.is_visible_in_tree():
        return
    FX.shared(self).burst("arrow", global_position, actor.global_basis.z)
