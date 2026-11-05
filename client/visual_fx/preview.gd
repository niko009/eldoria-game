extends Node3D
## Deterministic offline showcase: no Main, network, account or persistence.
## -- --low --capture-dir=<absolute path> --baseline (for a baseline worktree)
const ACTOR := preload("res://animated_actor.gd")
const WOLF := preload("res://wolf_actor.gd")
const PASSIVE := preload("res://passive_actor.gd")
const FX := preload("res://visual_fx/effect_pool.gd")
const PHASES := ["idle", "run", "attack", "cast", "equipment", "harvest", "hit", "death"]
var actors: Array[Node3D] = []
var wolf: Node3D
var deer: Node3D
var rabbit: Node3D
var label: Label
var high := true
var baseline := false
var capture_dir := ""
var phase := -1
var samples: Array[float] = []
var peak_draw_calls := 0
var peak_particles := 0
var sampling := false
var pool: Node3D
var last_frame_usec := 0

func _ready() -> void:
    high = not OS.get_cmdline_user_args().has("--low")
    baseline = OS.get_cmdline_user_args().has("--baseline")
    FX.high_detail = high
    DisplayServer.window_set_size(Vector2i(1280, 720))
    DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    Engine.max_fps = 120
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture-dir="):
            capture_dir = arg.trim_prefix("--capture-dir=")
    if not capture_dir.is_empty():
        DirAccess.make_dir_recursive_absolute(capture_dir)
    var environment := WorldEnvironment.new()
    environment.environment = Environment.new()
    environment.environment.background_mode = Environment.BG_COLOR
    environment.environment.background_color = Color("111d2b")
    environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.environment.ambient_light_color = Color("b5d1e3")
    environment.environment.ambient_light_energy = 0.65
    add_child(environment)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-50, -35, 0)
    sun.light_color = Color("ffe0ba")
    sun.light_energy = 1.5
    sun.shadow_enabled = high
    add_child(sun)
    var camera := Camera3D.new()
    add_child(camera)
    camera.position = Vector3(8.8, 7.2, 13.5)
    camera.look_at(Vector3(0, 0.9, 0))
    camera.projection = Camera3D.PROJECTION_ORTHOGONAL
    camera.size = 10.0
    camera.current = true
    _box(Vector3(0, -0.17, 0), Vector3(30, 0.25, 24), Color("243647"))
    for i in 3:
        _box(Vector3((i - 1) * 3.1, -0.03, 1.2), Vector3(2.75, 0.08, 2.9), Color("344d60"))
        var actor = ACTOR.new()
        actor.configure(860 + i, false, i)
        if not baseline:
            actor.preview_projectiles = true
        actor.position = Vector3((i - 1) * 3.1, 1, 1.2)
        add_child(actor)
        actors.append(actor)
    wolf = WOLF.new()
    add_child(wolf)
    wolf.update_state(Vector3(-3.1, 0, -2.2), 60, true)
    deer = PASSIVE.new()
    deer.setup("deer")
    add_child(deer)
    deer.update_state(Vector3(0, 0, -2.2), 55, true, Vector3.ZERO)
    rabbit = PASSIVE.new()
    rabbit.setup("rabbit")
    add_child(rabbit)
    rabbit.update_state(Vector3(3.1, 0, -2.2), 24, true, Vector3.ZERO)
    var canvas := CanvasLayer.new()
    add_child(canvas)
    label = Label.new()
    label.position = Vector2(40, 28)
    label.add_theme_font_size_override("font_size", 26)
    canvas.add_child(label)
    var footer := Label.new()
    footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
    footer.position = Vector2(40, get_viewport().get_visible_rect().size.y - 45)
    footer.text = "ELDORIA  /  TASK–086     •     Knight / Rogue / Mage     •     Offline visual laboratory"
    footer.add_theme_font_size_override("font_size", 18)
    canvas.add_child(footer)
    if not baseline:
        pool = FX.shared(self)
    _sequence()

func _box(at: Vector3, size: Vector3, color: Color) -> void:
    var instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    mesh.material = material
    instance.mesh = mesh
    instance.position = at
    add_child(instance)

func _sequence() -> void:
    await get_tree().create_timer(2.0).timeout
    for index in PHASES.size():
        phase = index
        label.text = "%s   /   %s   /   %s" % ["BASELINE" if baseline else "TASK–086", "HIGH" if high else "LOW", PHASES[phase].to_upper()]
        for actor in actors:
            if actor.has_method("play_visual_event"):
                actor.play_visual_event(&"idle")
            actor.emote_until_msec = 0
            actor.set_motion(Vector3.ZERO)
        _action()
        await get_tree().create_timer(0.22 if phase == 2 else 0.65 if phase == 7 else 0.3).timeout
        if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
            await RenderingServer.frame_post_draw
            var error := get_viewport().get_texture().get_image().save_png(capture_dir.path_join(PHASES[phase] + ".png"))
            if error != OK:
                push_error("Screenshot failed: " + str(error))
                get_tree().quit(1)
                return
        await get_tree().create_timer(0.6).timeout
    # Controlled six-second sustained load after warmup, excluding PNG encoding.
    phase = 1
    for actor in actors:
        if not baseline:
            actor.play_visual_event(&"idle")
    sampling = true
    for i in 30:
        for actor in actors:
            actor.hero_ability_animation(["taunt", "dash", "spell"][actors.find(actor)])
        if not baseline:
            pool.burst("heal", Vector3(0, 0.2, 0))
        await get_tree().create_timer(0.2).timeout
    sampling = false
    samples.sort()
    var total := 0.0
    for value in samples:
        total += value
    var report := {"profile": "high" if high else "low", "baseline": baseline,
        "platform": OS.get_name(), "renderer": RenderingServer.get_video_adapter_name(),
        "frames": samples.size(), "seconds": total, "mean_fps": samples.size() / maxf(total, 0.001),
        "p95_ms": samples[int(samples.size() * 0.95)] * 1000.0 if not samples.is_empty() else 0.0,
        "peak_draw_calls": peak_draw_calls, "peak_particles": peak_particles,
        "static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
        "resolution": "1280x720", "fps_cap": 120, "vsync": false}
    print("TASK086 PREVIEW ", JSON.stringify(report))
    if not capture_dir.is_empty():
        var file := FileAccess.open(capture_dir.path_join("metrics.json"), FileAccess.WRITE)
        file.store_string(JSON.stringify(report, "  ") + "\n")
    get_tree().quit(0)

func _action() -> void:
    match phase:
        0: pass
        1: pass # refreshed in _process, as network motion normally is
        2:
            actors[0].set_combat_equipped("spear")
            actors[1].set_combat_equipped("bow")
            actors[2].set_combat_equipped("unarmed")
            for actor in actors:
                actor.melee_attack()
            wolf.play_bite()
        3:
            for i in 3:
                actors[i].hero_ability_animation(["taunt", "dash", "spell"][i])
        4:
            actors[0].set_combat_equipped("shield")
            actors[1].set_combat_equipped("unarmed")
            actors[1].set_axe_equipped(true)
            actors[2].set_combat_equipped("staff")
            actors[2].set_offhand_equipped("shield")
        5:
            for actor in actors:
                actor.set_combat_equipped("unarmed")
                actor.set_axe_equipped(true)
                actor.gather("wood")
        6:
            for actor in actors:
                actor.hit_reaction()
            wolf.update_state(wolf.position, 30, true)
            deer.update_state(deer.position, 20, true, Vector3.ZERO)
            rabbit.update_state(rabbit.position, 10, true, Vector3.ZERO)
        7:
            for actor in actors:
                if actor.has_method("play_visual_event"):
                    actor.play_visual_event(&"death")
            wolf.update_state(wolf.position, 0, false)
            deer.update_state(deer.position, 0, false, Vector3.ZERO)
            rabbit.update_state(rabbit.position, 0, false, Vector3.ZERO)

func _process(delta: float) -> void:
    var now := Time.get_ticks_usec()
    var wall_delta := float(now - last_frame_usec) / 1000000.0 if last_frame_usec > 0 else delta
    last_frame_usec = now
    if phase == 1:
        for actor in actors:
            actor.set_motion(Vector3(0, 0, 7), true)
        if not sampling:
            wolf.update_state(wolf.position, 60, true, Vector3.RIGHT)
            deer.speed_visual = 2.8
            rabbit.speed_visual = 2.0
    elif phase >= 0:
        deer.speed_visual = 0.0
        rabbit.speed_visual = 0.0
    if sampling:
        samples.append(wall_delta)
        peak_draw_calls = maxi(peak_draw_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
        if pool != null:
            peak_particles = maxi(peak_particles, pool.particles.size())
