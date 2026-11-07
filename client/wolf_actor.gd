extends Node3D
class_name EldoriaWolfActor
## Visual representation of a server-owned wolf. All damage, AI and positions
## remain authoritative in main.gd; these animations never move a hitbox.

const WOLF_SCENE: PackedScene = preload("res://assets/wildlife/Wolf.glb")
const MODEL_SCALE := 0.47
const DEATH_VISIBLE_SECONDS := 1.7

var body: Node3D
var model: Node3D
var animator: AnimationPlayer
var skin_mesh: MeshInstance3D
var health_bar: MeshInstance3D
var health_text: Label3D
var health_focus := false
var health_reveal_until := 0
var visual_hp := 60
var max_health := 60
var down := false
var moving := false
var stride := 0.0
var bite_count := 0
var hurt_count := 0
var current_clip := ""
var initialized := false
var _wanted_locomotion := "Idle"
var _action_until_msec := 0
var _death_generation := 0
var _flash_tween: Tween
var _target_yaw := 0.0
var presentation := preload("res://visual_fx/creature_motion.gd").new()

func _ready() -> void:
    # Wait for the first authoritative snapshot before showing this actor.
    visible = false
    body = Node3D.new()
    body.name = "VisualRoot"
    add_child(body)
    model = WOLF_SCENE.instantiate()
    model.name = "RiggedWolf"
    # Quaternius faces +Z. Eldoria server heading uses -Z.
    model.rotation.y = PI
    model.scale = Vector3.ONE * MODEL_SCALE
    body.add_child(model)
    animator = model.get_node_or_null("AnimationPlayer")
    var meshes := model.find_children("*", "MeshInstance3D", true, false)
    if not meshes.is_empty():
        skin_mesh = meshes[0]
        skin_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    if animator != null:
        for name in ["Idle", "Walk", "Gallop", "Attack", "Idle_HitReact_Left", "Idle_HitReact_Right", "Death"]:
            var clip := animator.get_animation(name)
            if clip != null:
                clip.loop_mode = Animation.LOOP_LINEAR if name in ["Idle", "Walk", "Gallop"] else Animation.LOOP_NONE
        _play_clip("Idle")
    health_bar = MeshInstance3D.new()
    health_bar.name = "Health"
    var health_mesh := BoxMesh.new()
    health_mesh.size = Vector3(0.85, 0.065, 0.08)
    health_bar.mesh = health_mesh
    health_bar.position.y = 1.41
    var red := StandardMaterial3D.new()
    red.albedo_color = Color("af3f3b")
    red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    health_bar.material_override = red
    body.add_child(health_bar)
    health_text = Label3D.new()
    health_text.name = "HealthValue"
    health_text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    health_text.font_size = 30
    health_text.outline_size = 7
    health_text.modulate = Color("fff2e0")
    health_text.position.y = 1.65
    body.add_child(health_text)
    _update_health()

func update_state(point: Vector3, hp: int, alive: bool, direction: Vector3 = Vector3.ZERO) -> void:
    var distance := position.distance_to(point)
    position = point
    var health := clampi(hp, 0, max_health)
    if alive and (down or not initialized):
        _death_generation += 1
        down = false
        # A new life must not inherit the previous life's damage-reveal timer.
        health_reveal_until = 0
        visible = true
        _action_until_msec = 0
        _wanted_locomotion = "Idle"
        _play_clip("Idle")
        _reset_hit_overlay()
    if alive and initialized and health < visual_hp and not down:
        play_hit_reaction()
        health_reveal_until = Time.get_ticks_msec() + 3000
    if not alive and not down:
        if initialized:
            _play_death()
        else:
            down = true
            visible = false
    initialized = true
    visual_hp = health
    if alive and direction.length_squared() > 0.01:
        _target_yaw = atan2(-direction.x, -direction.z)
    moving = alive and direction.length_squared() > 0.01
    # Network positions are already interpolated by the world tick. The GLB
    # locomotion is in-place and does not alter the player's world collision.
    _wanted_locomotion = "Gallop" if moving and distance > 0.34 else ("Walk" if moving else "Idle")
    _update_health()

func _process(delta: float) -> void:
    _refresh_health_visibility()
    if down or animator == null:
        return
    rotation.y = lerp_angle(rotation.y, _target_yaw, 1.0 - exp(-10.0 * delta))
    presentation.step(self, delta, moving, global_position)
    if Time.get_ticks_msec() < _action_until_msec:
        return
    if current_clip != _wanted_locomotion:
        _play_clip(_wanted_locomotion, 0.14)

func play_bite() -> void:
    if down or animator == null:
        return
    bite_count += 1
    _play_action("Attack", 0.65)

func play_hit_reaction() -> void:
    if down or animator == null:
        return
    hurt_count += 1
    preload("res://visual_fx/effect_pool.gd").shared(self).burst("hit", global_position + Vector3.UP * 0.65)
    _play_action("Idle_HitReact_Left" if hurt_count % 2 else "Idle_HitReact_Right", 0.48)
    if skin_mesh != null:
        _reset_hit_overlay()
        var overlay := StandardMaterial3D.new()
        overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        overlay.albedo_color = Color(1.0, 0.35, 0.22, 0.53)
        skin_mesh.material_overlay = overlay
        _flash_tween = create_tween()
        _flash_tween.tween_property(overlay, "albedo_color:a", 0.0, 0.3)
        _flash_tween.tween_callback(_reset_hit_overlay)

func _reset_hit_overlay() -> void:
    if _flash_tween != null and _flash_tween.is_running():
        _flash_tween.kill()
    _flash_tween = null
    if skin_mesh != null:
        skin_mesh.material_overlay = null

func _play_death() -> void:
    down = true
    moving = false
    visible = true
    health_bar.visible = false
    _death_generation += 1
    _reset_hit_overlay()
    _play_clip("Death", 0.12)
    _hide_after_death(_death_generation)

func _hide_after_death(generation: int) -> void:
    await get_tree().create_timer(DEATH_VISIBLE_SECONDS).timeout
    if is_instance_valid(self) and down and generation == _death_generation:
        visible = false

func _play_action(name: String, seconds: float) -> void:
    var clip: Animation = animator.get_animation(name)
    if clip == null:
        return
    _action_until_msec = Time.get_ticks_msec() + int(seconds * 1000.0)
    _play_clip(name, 0.08, clip.length / seconds)

func _play_clip(name: String, fade: float = 0.08, speed: float = 1.0) -> void:
    if animator == null or not animator.has_animation(name):
        return
    current_clip = name
    animator.play(name, fade, speed)

func _update_health() -> void:
    if health_bar != null:
        health_bar.visible = not down and visual_hp > 0
        health_bar.scale.x = maxf(0.01, float(visual_hp) / float(max_health))
    if health_text != null:
        health_text.text = "%d / %d" % [visual_hp,max_health]
    _refresh_health_visibility()

func set_health_focus(focused: bool) -> void:
    health_focus = focused
    _refresh_health_visibility()

func _refresh_health_visibility() -> void:
    var show_hp := initialized and not down and visual_hp > 0 and (health_focus or Time.get_ticks_msec() < health_reveal_until)
    if health_bar != null:
        health_bar.visible = show_hp
    if health_text != null:
        health_text.visible = show_hp
