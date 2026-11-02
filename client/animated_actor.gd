extends Node3D

# KayKit CC0 humanoid: one common actor wrapper for local and remote clients.
# The multiplayer scene still owns positions/authority. Animation is visual-only.
const KNIGHT := preload("res://assets/characters/Knight.glb")
const ROGUE := preload("res://assets/characters/Rogue_Hooded.glb")
const MAGE := preload("res://assets/characters/Mage.glb")
const CLIPS := ["Idle", "Walking_A", "Running_A", "Cheer"]

var player_id := 0
var headless := false
var visual: Node3D
var animator: AnimationPlayer
var current_clip := ""
var animation_changes := 0
var last_motion_msec := 0
var emote_until_msec := 0
var model_kind := ""
var _last_move_vector := Vector3.ZERO

func configure(id: int, server_only: bool) -> void:
    player_id = id
    headless = server_only

func _ready() -> void:
    if headless:
        return
    var options: Array[PackedScene] = [KNIGHT, ROGUE, MAGE]
    var choice := posmod(player_id, options.size())
    model_kind = ["Knight", "Rogue_Hooded", "Mage"][choice]
    visual = options[choice].instantiate() as Node3D
    visual.name = "Animated_" + model_kind
    visual.position.y = -1.0  # Position protocol stores capsule center y=ground+1.
    add_child(visual)
    animator = visual.get_node_or_null("AnimationPlayer") as AnimationPlayer
    if animator == null:
        push_error("KayKit " + model_kind + " is missing AnimationPlayer")
        return
    for clip in CLIPS:
        var animation := animator.get_animation(clip)
        if animation == null:
            push_error("Missing KayKit animation " + clip)
            continue
        if clip != "Cheer":
            animation.loop_mode = Animation.LOOP_LINEAR
        else:
            animation.loop_mode = Animation.LOOP_NONE
    # Accessories are optional, but keep only the recognizable outfit, not
    # every alternative shield, melee weapon, and hat in the original GLB.
    _hide_unused_accessories(visual)
    set_clip("Idle")

func _hide_unused_accessories(node: Node) -> void:
    for child in node.get_children():
        if child is MeshInstance3D and String(child.name).contains("Sword_Offhand"):
            child.visible = false
        elif child is MeshInstance3D and (String(child.name).contains("Shield") or
                String(child.name).contains("Crossbow") or String(child.name).contains("Wand") or
                String(child.name).contains("Staff") or String(child.name).contains("Knife") or
                String(child.name).contains("Spellbook")):
            child.visible = false
        _hide_unused_accessories(child)

func set_clip(clip: String) -> void:
    if animator == null or current_clip == clip or not animator.has_animation(clip):
        return
    current_clip = clip
    animation_changes += 1
    animator.play(clip, 0.14)

func set_motion(velocity: Vector3, sprinting: bool = false) -> void:
    # Call every physics frame for own avatar, or whenever the remote
    # position packet arrives. Remote idle comes from timeout below.
    if headless:
        return
    var flat := Vector3(velocity.x, 0.0, velocity.z)
    if flat.length_squared() < 0.02:
        if Time.get_ticks_msec() >= emote_until_msec:
            set_clip("Idle")
        return
    last_motion_msec = Time.get_ticks_msec()
    if flat.length_squared() > 0.04:
        var target_yaw := atan2(-flat.x, -flat.z)
        rotation.y = lerp_angle(rotation.y, target_yaw, 0.24)
    if Time.get_ticks_msec() < emote_until_msec:
        return
    set_clip("Running_A" if sprinting or flat.length() > 5.5 else "Walking_A")

func celebrate() -> void:
    if headless or animator == null:
        return
    var clip := animator.get_animation("Cheer")
    if clip == null:
        return
    emote_until_msec = Time.get_ticks_msec() + int(clip.length * 1000)
    current_clip = ""
    set_clip("Cheer")

func _process(_delta: float) -> void:
    if headless:
        return
    if Time.get_ticks_msec() > emote_until_msec and last_motion_msec > 0 and             Time.get_ticks_msec() - last_motion_msec > 300:
        set_clip("Idle")
