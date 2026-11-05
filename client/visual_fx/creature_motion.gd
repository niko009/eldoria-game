extends RefCounted
## Procedural reactions for rigs without hit/death clips. Never move actor roots.
const FX := preload("res://visual_fx/effect_pool.gd")
var reaction: Tween
var step_clock := 0.0
var corpses: Array[Node3D] = []

func step(context: Node3D, delta: float, walking: bool, ground: Vector3) -> void:
    step_clock += delta
    if walking and context.is_visible_in_tree() and step_clock >= 0.3:
        step_clock = 0.0
        FX.shared(context).burst("dust", ground + Vector3.UP * 0.025)

func hit(context: Node3D, body: Node3D) -> void:
    reset(body)
    FX.shared(context).burst("hit", context.global_position + Vector3.UP * 0.6)
    reaction = context.create_tween()
    reaction.tween_property(body, "rotation:z", -0.13, 0.07)
    reaction.tween_property(body, "rotation:z", 0.0, 0.23)

func reset(body: Node3D) -> void:
    if reaction != null:
        reaction.kill()
    reaction = null
    body.rotation = Vector3.ZERO
    body.position.y = 0.0

func death(context: Node3D, body: Node3D) -> void:
    reset(body)
    # Actor immediately follows authoritative visibility. Only a short cosmetic
    # clone falls over; it has no collision, target ID, health bar or AI.
    var pool = FX.shared(context)
    var maximum := 4 if FX.high_detail else 2
    if pool.get_child_count() >= maximum + 1 or not pool.is_inside_tree():
        return
    var corpse := body.duplicate() as Node3D
    corpse.name = "CosmeticCorpse"
    pool.add_child(corpse)
    corpse.global_transform = body.global_transform
    for node in corpse.find_children("*", "AnimationPlayer", true, false):
        node.stop(true)
    for node in corpse.get_children():
        if node is MeshInstance3D:
            node.visible = false # health bars; wildlife is inside WildlifeModel
    corpses.append(corpse)
    var fall := corpse.create_tween()
    fall.tween_property(corpse, "rotation:z", corpse.rotation.z + 1.35, 0.5).set_trans(Tween.TRANS_SINE)
    fall.tween_interval(0.4)
    fall.tween_property(corpse, "scale", Vector3.ONE * 0.01, 0.25)
    fall.tween_callback(corpse.queue_free)

func clear_corpses() -> void:
    for corpse in corpses:
        if is_instance_valid(corpse):
            corpse.queue_free()
    corpses.clear()
