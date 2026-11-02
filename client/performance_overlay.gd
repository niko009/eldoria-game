extends CanvasLayer

# Local, opt-in diagnostics. No identity, coordinates or network export.
const WINDOW := 300
var game: Node3D
var _samples: Array[float] = []
var _elapsed := 0.0
var _label: Label

func _ready() -> void:
    layer = 20
    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    panel.offset_left = -272
    panel.offset_top = 12
    panel.offset_right = -12
    panel.offset_bottom = 200
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.035, 0.065, 0.09, 0.89)
    style.border_color = Color(0.69, 0.53, 0.28, 0.8)
    style.set_border_width_all(1)
    style.set_corner_radius_all(10)
    style.set_content_margin_all(10)
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)
    _label = Label.new()
    _label.add_theme_color_override("font_color", Color("e9e7d4"))
    _label.add_theme_font_size_override("font_size", 13)
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(_label)
    visible = false
    set_process(false)

func toggle() -> void:
    visible = not visible
    set_process(visible)
    _samples.clear()
    _elapsed = 0.0
    if visible:
        _label.text = "Performance: warming up..."

func _process(delta: float) -> void:
    if delta <= 0.0 or game == null:
        return
    _samples.append(delta * 1000.0)
    if _samples.size() > WINDOW:
        _samples.pop_front()
    _elapsed += delta
    if _elapsed < 1.0 or _samples.size() < 2:
        return
    _elapsed = 0.0
    var sorted := _samples.duplicate()
    sorted.sort()
    var total := 0.0
    for ms in _samples:
        total += ms
    var p95: float = sorted[clampi(ceili(sorted.size() * 0.95) - 1, 0, sorted.size() - 1)]
    var avg := 1000.0 * _samples.size() / total
    var low := 1000.0 / maxf(p95, 0.1)
    var world: Node3D = game.get_node("Eldoria_Forest")
    var camera: Camera3D = game.camera
    var size := get_viewport().get_visible_rect().size
    var counts := _visible_counts(world, camera, size)
    var flat := Vector2(camera.position.x + 29.0, camera.position.z - 22.0)
    var scene := "lake" if flat.length() < 22.0 else ("camp" if Vector2(camera.position.x, camera.position.z).length() < 22.0 else "forest")
    var render_data := "нет данных"
    var cpu_data := "нет данных"
    if DisplayServer.get_name() != "headless":
        render_data = "%d / %d" % [int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))]
        cpu_data = "%.1f / %.1f ms" % [Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0]
    _label.text = "FPS avg / 5%% low: %.1f / %.1f\np95 frame: %.1f ms\nCPU / physics: %s\n3D objects / draws: %s\nQuality: %s  |  %s\nVisible trees / details: %d / %d\nViewport: %d x %d\nMemory RSS: нет данных" % [avg, low, p95, cpu_data, render_data, "Low" if game.graphics_quality == 0 else "High", scene, counts.x, counts.y, int(size.x), int(size.y)]

func _visible_counts(world: Node3D, camera: Camera3D, size: Vector2) -> Vector2i:
    var counts := Vector2i.ZERO
    for key in world._batch_nodes_by_key:
        var batch: MultiMeshInstance3D = world._batch_nodes_by_key[key]
        if not batch.visible:
            continue
        var is_tree: bool = String(key).begins_with("CommonTree") or String(key).begins_with("Pine") or String(key).begins_with("TwistedTree")
        for i in range(batch.multimesh.instance_count):
            var position: Vector3 = batch.multimesh.get_instance_transform(i).origin + Vector3.UP
            if camera.global_position.distance_to(position) > camera.far or camera.is_position_behind(position):
                continue
            var screen := camera.unproject_position(position)
            if screen.x < 0 or screen.y < 0 or screen.x > size.x or screen.y > size.y:
                continue
            if is_tree:
                counts.x += 1
            else:
                counts.y += 1
    return counts
