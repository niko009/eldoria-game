extends Node3D

# KayKit CC0 humanoid: one common actor wrapper for local and remote clients.
# The multiplayer scene still owns positions/authority. Animation is visual-only.
const AVATARS := preload("res://avatar_profile.gd")
const KNIGHT := preload("res://assets/characters/Knight.glb")
const ROGUE := preload("res://assets/characters/Rogue_Hooded.glb")
const MAGE := preload("res://assets/characters/Mage.glb")
const AXE_VISUAL := preload("res://stone_axe_visual.gd")
const VISUAL_EVENTS := preload("res://visual_fx/actor_events.gd")
const BOW_MOTION := preload("res://visual_fx/bow_motion.gd")
const EFFECTS := preload("res://visual_fx/effect_pool.gd")
signal visual_action(event: StringName)
var visual_dead := false
var _locomotion := "Idle"
var _footsteps := preload("res://visual_fx/creature_motion.gd").new()
const ACTION_CLIPS := ["Cheer","PickUp","1H_Melee_Attack_Chop",
    "2H_Ranged_Shoot","2H_Melee_Attack_Stab","Block_Hit",
    "Unarmed_Melee_Attack_Punch_A","Spellcast_Shoot","Dodge_Forward","Hit_A",
    "Death_A","2H_Ranged_Aiming","Interact"]
const CLIPS := ["Idle", "Walking_A", "Running_A", "Cheer",
    "Jump_Start", "Jump_Idle", "Jump_Land", "PickUp", "1H_Melee_Attack_Chop",
    "2H_Ranged_Shoot","2H_Melee_Attack_Stab","Block_Hit",
    "Unarmed_Melee_Attack_Punch_A","Spellcast_Shoot","Dodge_Forward","Hit_A",
    "Death_A","2H_Ranged_Aiming","Interact"]

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
var axe_equipped := false
var axe_visual: Node3D
var combat_item := "unarmed"
var combat_visual: Node3D

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
    axe_visual = null
    combat_visual = null
    offhand_visual = null
    current_clip = ""
    _create_visual()
    _set_offhand_visual()

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
        animation.loop_mode = Animation.LOOP_NONE if clip in ACTION_CLIPS else Animation.LOOP_LINEAR
    # Accessories are optional, but keep only the recognizable outfit, not
    # every alternative shield, melee weapon, and hat in the original GLB.
    _hide_unused_accessories(visual)
    _attach_equipment()
    set_clip("Idle")

func _attach_equipment() -> void:
    # All three KayKit humanoids ship a skinned right-hand socket. Reuse the
    # imported BoneAttachment3D so the weapon follows walking and chop clips.
    var hand := visual.get_node_or_null("Rig/Skeleton3D/handslot_r") as BoneAttachment3D
    if hand == null:
        push_error("Missing right-hand weapon socket for KayKit " + model_kind)
        return
    axe_visual = AXE_VISUAL.new()
    hand.add_child(axe_visual)
    # Imported KayKit handslot: +Z points up in the neutral hand pose.
    # Re-orient our axe's +Y handle into the hand's +Z rather than forward.
    axe_visual.rotation_degrees = Vector3(90, 0, 0)
    axe_visual.visible = axe_equipped
    _set_combat_visual()

func set_combat_equipped(item: String) -> void:
    var changed := combat_item != item
    combat_item = item
    _set_combat_visual()
    if changed and not visual_dead and not airborne:
        _play_action_clip("Interact", 0.3)

var offhand_item := "unarmed"
var offhand_visual: Node3D

func set_offhand_equipped(item: String) -> void:
    offhand_item = item
    _set_offhand_visual()

func _set_offhand_visual() -> void:
    if offhand_visual != null:
        offhand_visual.queue_free()
        offhand_visual = null
    if headless or visual == null or offhand_item != "shield":
        return
    var hand := visual.get_node_or_null("Rig/Skeleton3D/handslot_l") as BoneAttachment3D
    if hand == null:
        return
    offhand_visual = Node3D.new()
    offhand_visual.name = "OffhandShield"
    hand.add_child(offhand_visual)
    var shield := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.37
    mesh.bottom_radius = 0.37
    mesh.height = 0.09
    shield.mesh = mesh
    shield.rotation_degrees.x = 90
    shield.material_override = _equipment_material(Color("8a7756"))
    offhand_visual.add_child(shield)
    offhand_visual.rotation_degrees.x = 90

func _set_combat_visual() -> void:
    if combat_visual != null:
        combat_visual.queue_free()
        combat_visual = null
    if axe_visual != null:
        axe_visual.visible = axe_equipped and combat_item == "unarmed"
    if headless or visual == null or (combat_item in ["unarmed", "staff", "wooden_staff"] and avatar_choice != 2):
        return
    var hand := visual.get_node_or_null("Rig/Skeleton3D/handslot_r") as BoneAttachment3D
    if hand == null:
        return
    combat_visual = Node3D.new()
    combat_visual.name = "CombatEquipment"
    hand.add_child(combat_visual)
    if combat_item in ["unarmed", "staff", "wooden_staff"] and avatar_choice == 2:
        _equipment_segment("MageStaff",Vector3(0,-0.55,0),Vector3(0,0.95,0),0.045,Color("665078"))
        var crystal := MeshInstance3D.new()
        crystal.name = "StaffCrystal"
        var gem := SphereMesh.new()
        gem.radius = 0.13
        gem.height = 0.26
        crystal.mesh = gem
        crystal.position.y = 1.05
        var material := _equipment_material(Color("62d5ff"))
        material.emission_enabled = true
        material.emission = Color("247ecf")
        material.emission_energy_multiplier = 2.0
        crystal.material_override = material
        combat_visual.add_child(crystal)
    elif combat_item == "spear":
        # A long wooden shaft with a tapered steel head is readable in third person.
        _equipment_segment("SpearShaft", Vector3(0,-0.75,0), Vector3(0,0.92,0),
            0.037,Color("926644"))
        _equipment_segment("SpearSocket", Vector3(0,0.91,0), Vector3(0,1.04,0),
            0.07,Color("859b9f"))
        var point := MeshInstance3D.new()
        point.name = "SteelSpearPoint"
        var steel := CylinderMesh.new()
        steel.bottom_radius = 0.12
        steel.top_radius = 0.0
        steel.height = 0.42
        point.mesh = steel
        point.position.y = 1.24
        point.material_override = _equipment_material(Color("d6e2df"))
        combat_visual.add_child(point)
    elif combat_item == "bow":
        # Two curved wooden limbs and a taut string. The old bow was a cylinder.
        var parts := [Vector3(0,0,0),Vector3(0.17,0.30,0),Vector3(0.22,0.65,0),
            Vector3(0.12,0.82,0)]
        for i in 3:
            _equipment_segment("BowUpper_%d" % i,parts[i],parts[i+1],0.055,
                Color("a87848"))
            _equipment_segment("BowLower_%d" % i,
                Vector3(parts[i].x,-parts[i].y,0),Vector3(parts[i+1].x,-parts[i+1].y,0),
                0.055,Color("a87848"))
        _equipment_segment("BowString",Vector3(0.12,-0.82,0),Vector3(0.12,0.82,0),
            0.009,Color("e9e2c9"))
        _equipment_segment("BowGrip",Vector3(0,-0.12,0),Vector3(0,0.12,0),
            0.07,Color("5a4936"))
    elif combat_item == "shield":
        var body := MeshInstance3D.new()
        var mesh := CylinderMesh.new()
        mesh.top_radius = 0.37
        mesh.bottom_radius = 0.37
        mesh.height = 0.09
        body.rotation_degrees.x = 90
        body.mesh = mesh
        body.material_override = _equipment_material(Color("8a7756"))
        combat_visual.add_child(body)
        var boss := MeshInstance3D.new()
        boss.name = "ShieldBoss"
        var boss_mesh := SphereMesh.new()
        boss_mesh.radius = 0.09
        boss_mesh.height = 0.18
        boss.mesh = boss_mesh
        boss.material_override = _equipment_material(Color("d6d0b5"))
        boss.position.z = 0.09
        combat_visual.add_child(boss)
    else:
        return
    combat_visual.rotation_degrees.x = 90
    if combat_item == "bow":
        var bow_motion := BOW_MOTION.new()
        bow_motion.name = "BowMotion"
        combat_visual.add_child(bow_motion)
        bow_motion.setup(self, combat_visual.get_node("BowString"))
    if axe_visual != null:
        axe_visual.visible = axe_equipped and combat_item == "unarmed"

func _equipment_material(color: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.76
    return material

func _equipment_segment(name: String, a: Vector3, b: Vector3, width: float, color: Color) -> void:
    var segment := MeshInstance3D.new()
    segment.name = name
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = width
    cylinder.bottom_radius = width
    cylinder.height = a.distance_to(b)
    segment.mesh = cylinder
    segment.position = (a+b)*0.5
    segment.quaternion = Quaternion(Vector3.UP,(b-a).normalized())
    segment.material_override = _equipment_material(color)
    combat_visual.add_child(segment)

func set_axe_equipped(value: bool) -> void:
    # This is visual state only. The server still authorizes inventory and
    # wood yield. Never infer equipment from locally selected hotbar slots.
    axe_equipped = value
    if axe_visual != null:
        axe_visual.visible = value and combat_item == "unarmed"

func _hide_unused_accessories(node: Node) -> void:
    for child in node.get_children():
        if child is MeshInstance3D and String(child.name).contains("Sword"):
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

func play_visual_event(event: StringName, data: Dictionary = {}) -> bool:
    return VISUAL_EVENTS.dispatch(self, event, data)

func set_motion(velocity: Vector3, sprinting: bool = false) -> void:
    # Call every physics frame for own avatar, or whenever the remote
    # position packet arrives. Remote idle comes from timeout below.
    if headless or visual_dead:
        return
    var flat := Vector3(velocity.x, 0.0, velocity.z)
    _locomotion = "Idle" if flat.length_squared() < 0.02 else ("Running_A" if sprinting or flat.length() > 5.5 else "Walking_A")
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
    if headless or animator == null or airborne or visual_dead:
        return
    # A character without an equipped axe should not swing an invisible tool.
    # The selected clip is visual-only; the server authorizes yield separately.
    var chosen := "1H_Melee_Attack_Chop" if kind == "wood" and axe_equipped else "PickUp"
    var clip := animator.get_animation(chosen)
    if clip == null:
        return
    emote_until_msec = Time.get_ticks_msec() + int(clip.length*1000.0)
    current_clip = ""
    set_clip(chosen)
    EFFECTS.shared(self).burst("harvest", global_position + global_basis.z * 0.5)

func face_interaction(target: Vector3) -> void:
    # Turn toward the *validated* resource spot without modifying the
    # authoritative player position, velocity or facing on the server.
    if headless or airborne:
        return
    var direction := target - global_position
    direction.y = 0.0
    if direction.length_squared() > 0.02:
        rotation.y = atan2(direction.x, direction.z)

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
    if headless or animator == null or airborne or visual_dead:
        return
    # These are real KayKit clips present in all three imported skeletons.
    # Fit their visual duration to the 650-ms server attack cooldown.
    match combat_item:
        "bow":
            _play_action_clip("2H_Ranged_Shoot",0.52)
        "spear":
            _play_action_clip("2H_Melee_Attack_Stab",0.56)
        "shield":
            _play_action_clip("Block_Hit",0.52)
        _:
            _play_action_clip("Unarmed_Melee_Attack_Punch_A",0.56)
    if combat_item == "bow" and combat_visual != null:
        combat_visual.get_node("BowMotion").shoot()
        var recoil := create_tween()
        combat_visual.rotation_degrees.x = 65
        recoil.tween_property(combat_visual,"rotation_degrees:x",90.0,0.18)
    elif combat_item == "spear" and combat_visual != null:
        # Quick visible forward thrust followed by recovery. No client-side
        # movement or hit detection: damage remains server-authoritative.
        var thrust := create_tween()
        thrust.tween_property(combat_visual,"position:z",-0.38,0.11).set_trans(Tween.TRANS_QUAD)
        thrust.tween_property(combat_visual,"position:z",0.0,0.23).set_trans(Tween.TRANS_SINE)

func shield_block() -> void:
    if headless or combat_item != "shield" or combat_visual == null:
        return
    if combat_visual.has_meta("blocking"):
        return
    _play_action_clip("Block_Hit",0.46)
    combat_visual.set_meta("blocking",true)
    var shield_tween := create_tween()
    shield_tween.tween_property(combat_visual,"scale",Vector3(1.12,1.12,1.12),0.10)
    shield_tween.tween_property(combat_visual,"scale",Vector3.ONE,0.18)
    shield_tween.finished.connect(func() -> void:
        if is_instance_valid(combat_visual):
            combat_visual.remove_meta("blocking"))

func hero_ability_animation(kind: String) -> void:
    if headless or animator == null or airborne:
        return
    match kind:
        "dash":
            _play_action_clip("Dodge_Forward",0.38)
        "heal", "spell":
            _play_action_clip("Spellcast_Shoot",0.68)
        "taunt":
            _play_action_clip("Block_Hit",0.46)
    if kind in ["dash", "heal", "spell", "taunt"]:
        EFFECTS.shared(self).burst(kind, global_position, global_basis.z)

func hit_reaction() -> void:
    if headless or animator == null or airborne:
        return
    if combat_item == "shield":
        shield_block()
    else:
        _play_action_clip("Hit_A",0.37)

func _play_action_clip(clip: String, duration: float) -> void:
    if headless or animator == null or not animator.has_animation(clip):
        return
    var animation: Animation = animator.get_animation(clip)
    # Do not let movement packets or Idle truncate a successful attack.
    emote_until_msec = Time.get_ticks_msec() + int(duration*1000.0)
    current_clip = clip
    animation_changes += 1
    animator.play(clip,0.08,animation.length/maxf(0.10,duration))
    visual_action.emit(StringName(clip))

func _process(delta: float) -> void:
    if headless or visual_dead:
        return
    _footsteps.step(self, delta, not airborne and _locomotion != "Idle" and Time.get_ticks_msec() - last_motion_msec < 300, global_position - Vector3.UP)
    if airborne and current_clip == "Jump_Start" and animator.current_animation_position > 0.19:
        set_clip("Jump_Idle")
    if airborne or Time.get_ticks_msec() < landing_until_msec:
        return
    if Time.get_ticks_msec() > emote_until_msec and current_clip in ACTION_CLIPS:
        set_clip(_locomotion if Time.get_ticks_msec() - last_motion_msec <= 300 else "Idle")
    elif Time.get_ticks_msec() > emote_until_msec and last_motion_msec > 0 and Time.get_ticks_msec() - last_motion_msec > 300:
        set_clip("Idle")
