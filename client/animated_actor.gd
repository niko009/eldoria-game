extends Node3D

# KayKit CC0 humanoid: one common actor wrapper for local and remote clients.
# The multiplayer scene still owns positions/authority. Animation is visual-only.
const AVATARS := preload("res://avatar_profile.gd")
const KNIGHT := preload("res://assets/characters/Knight.glb")
const ROGUE := preload("res://assets/characters/Rogue_Hooded.glb")
const MAGE := preload("res://assets/characters/Mage.glb")
const CLIPS := ["Idle", "Walking_A", "Running_A", "Cheer", "Jump_Start", "Jump_Idle", "Jump_Land", "PickUp", "1H_Melee_Attack_Chop"]

var player_id := 0
var avatar_choice := -1
var headless := false
var visual: Node3D
var animator: AnimationPlayer
var current_clip := ""
var animation_changes := 0
var last_motion_msec := 0
var emote_until_msec := 0
var airborne := false
var landing_until_msec := 0
var model_kind := ""
var _last_move_vector := Vector3.ZERO

func configure(id: int, server_only: bool, choice: int = -1) -> void:
    player_id = id
    headless = server_only
    avatar_choice = choice if AVATARS.valid(choice) else posmod(id, AVATARS.NAMES.size())

func _ready() -> void:
    if headless:
        model_kind = AVATARS.NAMES[avatar_choice]
        return
    _create_visual()

func set_avatar(choice: int) -> void:
    if not AVATARS.valid(choice) or avatar_choice == choice:
        return
    avatar_choice = choice
    if headless:
        model_kind = AVATARS.NAMES[choice]
        return
    if visual != null:
        remove_child(visual)
        visual.queue_free()
        visual = null
    animator = null
    current_clip = ""
    _create_visual()

func _create_visual() -> void:
    var options: Array[PackedScene] = [KNIGHT, ROGUE, MAGE]
    model_kind = AVATARS.NAMES[avatar_choice]
    visual = options[avatar_choice].instantiate() as Node3D
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
        if clip not in ["Cheer", "PickUp", "1H_Melee_Attack_Chop"]:
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
        # KayKit characters face local +Z, unlike Godot's usual -Z forward.
        # Rotate their +Z-facing model toward the actual motion vector.
        var target_yaw := atan2(flat.x, flat.z)
        rotation.y = lerp_angle(rotation.y, target_yaw, 0.24)
    if airborne or Time.get_ticks_msec() < landing_until_msec or Time.get_ticks_msec() < emote_until_msec:
        return
    set_clip("Running_A" if sprinting or flat.length() > 5.5 else "Walking_A")

func start_jump() -> void:
    if headless or animator == null:
        return
    airborne = true
    landing_until_msec = 0
    set_clip("Jump_Start")

func finish_jump() -> void:
    if headless or animator == null:
        return
    airborne = false
    landing_until_msec = Time.get_ticks_msec() + 160
    set_clip("Jump_Land")

func gather(kind: String = "herb") -> void:
    if headless or animator == null or airborne:
        return
    var chosen := "1H_Melee_Attack_Chop" if kind == "wood" else "PickUp"
    var clip := animator.get_animation(chosen)
    if clip == null:
        return
    emote_until_msec = Time.get_ticks_msec() + int(clip.length*1000.0)
    current_clip = ""
    set_clip(chosen)

func celebrate() -> void:
    if headless or animator == null:
        return
    var clip := animator.get_animation("Cheer")
    if clip == null:
        return
    emote_until_msec = Time.get_ticks_msec() + int(clip.length * 1000)
    current_clip = ""
    set_clip("Cheer")

func melee_attack() -> void:
    if headless or animator == null or airborne:
        return
    var clip := animator.get_animation("1H_Melee_Attack_Chop")
    if clip == null:
        return
    emote_until_msec = Time.get_ticks_msec() + int(clip.length * 1000.0)
    current_clip = ""
    set_clip("1H_Melee_Attack_Chop")

func _process(_delta: float) -> void:
    if headless:
        return
    if airborne and current_clip == "Jump_Start" and animator.current_animation_position > 0.19:
        set_clip("Jump_Idle")
    if airborne or Time.get_ticks_msec() < landing_until_msec:
        return
    if Time.get_ticks_msec() > emote_until_msec and current_clip in ["Cheer", "PickUp", "1H_Melee_Attack_Chop"]:
        set_clip("Idle")
    elif Time.get_ticks_msec() > emote_until_msec and last_motion_msec > 0 and Time.get_ticks_msec() - last_motion_msec > 300:
        set_clip("Idle")
