extends Node3D

# One Godot scene, one replication protocol and one set of mechanics for all exports.
# The current ENet session is an MVP transport, not the planned authoritative .NET protocol.
const PORT := 7777
const WEBSOCKET_PORT := 7788
const MAX_PLAYERS := 10
const INPUT_SCRIPT := preload("res://platform_input.gd")
const RESOURCE_TARGETING := preload("res://resource_targeting.gd")
const JOYSTICK_SCRIPT := preload("res://mobile_joystick.gd")
const WORLD_SAVE_SCRIPT := preload("res://world_save.gd")
const POSTGRES_WORLD_STORE_SCRIPT := preload("res://postgres_world_store.gd")
const BUILDING_SCRIPT := preload("res://building_object.gd")
const HARVEST_VFX_SCRIPT := preload("res://harvest_vfx.gd")
const TELEMETRY_SCRIPT := preload("res://performance_telemetry.gd")
const TELEMETRY_SINK_SCRIPT := preload("res://telemetry_sink.gd")
const DISPLAY_SCRIPT := preload("res://display_settings.gd")
const GRAPHICS_SCRIPT := preload("res://graphics_profile.gd")
const AMBIENCE_SCRIPT := preload("res://environment_polish.gd")
const OVERLAY_SCRIPT := preload("res://performance_overlay.gd")
const FOREST_SCRIPT := preload("res://forest_world.gd")
const ACTOR_SCRIPT := preload("res://animated_actor.gd")
const WOLF_ACTOR_SCRIPT := preload("res://wolf_actor.gd")
const PASSIVE_SCRIPT := preload("res://passive_creatures.gd")
const PASSIVE_ACTOR_SCRIPT := preload("res://passive_actor.gd")
const RAID_SCRIPT := preload("res://camp_raid.gd")
const LIVE_UI_SCRIPT := preload("res://ui/live_ui.gd")
const AVATAR_PROFILE := preload("res://avatar_profile.gd")
const HERO_CLASSES := preload("res://hero_classes.gd")
const JUMP_MOTION := preload("res://jump_motion.gd")
const UPDATE_SCRIPT := preload("res://update_manager.gd")
const MOVE_SPEED := 6.0
const CLIENT_VERSION := "0.5.10-dev"
# TASK-039 is a development protocol: never auto-connect to production v0.5.9.

const DEVELOPMENT_BUILD := true
const SERVER_CONFIG_URL := "https://bacus.dev/projects/eldoria/server.json"

var peer: MultiplayerPeer = ENetMultiplayerPeer.new()
var players := {}
var player_choices := {}
var resource_remaining := {}
var player_inventories := {}
var player_health := {}
var player_respawn_at := {}
var last_attack_at := {}
const MAX_HEALTH := 100
const WOLF_MAX_HEALTH := 60
const WOLF_SPAWN := Vector3(17, 1, 15)
var wolf_position := WOLF_SPAWN
var wolf_health := WOLF_MAX_HEALTH
var wolf_alive := false
var wolf_respawn_at := 0
var wolf_last_hit_at := 0
var wolf_sync_timer := 0.0
var wolf_direction := Vector3.ZERO
var wolf_actor: Node3D
var pack_wolves: Dictionary = {}
var pack_actors: Dictionary = {}
var pack_sync_timer := 0.0
var passive_creatures: Dictionary = {}
var passive_actors: Dictionary = {}
var passive_sync_timer := 0.0
var practice_points: Dictionary = {}
var player_skills: Dictionary = {}
var training_last_hit: Dictionary = {}
const SKILL_KINDS := ["archery","spear","defense"]
const SKILL_XP_MAX := 1000000
const COMBAT_PROGRESSION := preload("res://combat_progression.gd")
const CAMP_MAX_HP := 120
var camp_hp := CAMP_MAX_HP
var camp_target_id := 0
var camp_last_hit := {}
var repair_cooldowns := {}
var equipped_combat := {}
const SHIELD_TAUNT_DURATION_MS := 5000
const SHIELD_TAUNT_COOLDOWN_MS := 15000
const SHIELD_TAUNT_RANGE := 10.0
var shield_taunt_until: Dictionary = {}
var shield_taunt_ready_at: Dictionary = {}
var hero_ability_ready_at: Dictionary = {}
var hero_mana: Dictionary = {}
const MAGE_SPELLS := ["fire", "frost", "storm"]
const MAGE_SPELL_COST := [14.0, 22.0, 34.0]
const MAGE_SPELL_DAMAGE := [18, 24, 34]
var mage_spell_index := 0
var mage_health_regen_accum := 0.0
var mage_chilled_until: Dictionary = {}

func _try_equip_combat(item: String) -> void:
    if own_id <= 0:
        return
    if multiplayer.is_server():
        _equip_combat_on_server(own_id,item)
    else:
        request_equip_combat.rpc_id(1,item)

@rpc("any_peer","reliable")
func request_equip_combat(item: String) -> void:
    if multiplayer.is_server():
        _equip_combat_on_server(multiplayer.get_remote_sender_id(),item)

func _equip_combat_on_server(id: int, item: String) -> bool:
    if not multiplayer.is_server() or not players.has(id) or not ["unarmed","spear","bow","shield"].has(item):
        return false
    if item != "unarmed" and int(player_inventories.get(id,{}).get(item,0)) < 1:
        return false
    equipped_combat[id] = item
    if item != "shield":
        shield_taunt_until.erase(id)
        if players.has(id):
            var marker: Node = players[id].get_node_or_null("TauntIndicator")
            if marker != null:
                marker.queue_free()
    combat_visual_snapshot.rpc(id,item)
    if players.has(id):
        players[id].set_combat_equipped(item)
    if id == own_id:
        combat_equip_snapshot(item)
    elif multiplayer.get_peers().has(id):
        combat_equip_snapshot.rpc_id(id,item)
    return true

@rpc("authority","call_remote","reliable")
func combat_equip_snapshot(item: String) -> void:
    if live_ui != null and ["unarmed","spear","bow","shield"].has(item):
        live_ui.set_combat_equipment(item)
        match item:
            "bow":
                var arrows: int = live_ui.state.amount("arrow")
                live_ui.show_message("Лук: %d стрел · атака J / УДАР" % arrows if arrows > 0
                    else "Лук экипирован. Создайте стрелы у костра.")
            "spear":
                live_ui.show_message("Копьё экипировано · атака J / УДАР")
            "shield":
                live_ui.show_message("Щит экипирован · навык рыцаря Q / УМЕНИЕ")
            _:
                live_ui.show_message("Без оружия")

@rpc("authority","call_remote","reliable")
func combat_visual_snapshot(id: int, item: String) -> void:
    if players.has(id) and ["unarmed","spear","bow","shield"].has(item):
        players[id].set_combat_equipped(item)
        if item != "shield":
            var indicator: Node = players[id].get_node_or_null("TauntIndicator")
            if indicator != null:
                indicator.queue_free()
var raid: RefCounted = RAID_SCRIPT.new()
var raid_next_broadcast := 0
var raid_anchor := Vector3.ZERO
var healing_cooldowns := {}
var equipped_axes := {} # Ephemeral server-authoritative equipment, reset on reconnect.
var player_identity_keys := {}
var persistent_profiles := {}
var world_store: RefCounted
var placed_buildings: Dictionary = {}
var building_nodes: Dictionary = {}
var next_building_id := 1
var build_selector: OptionButton
var build_feedback_label: Label
var build_feedback_until := 0
var preview_enabled := false
var preview_actor: Node3D
var preview_kind := ""
var preview_last_update_msec := 0
var preview_valid := false
var preview_spot := Vector3.INF
var harvest_visuals: Node3D
var mobile_build_panel: PanelContainer
var mobile_build_picker: OptionButton
var mobile_build_toggle: Button
var mobile_build_mode := false
var sound_button: Button
var telemetry: Node
var telemetry_sink: Node
var telemetry_button: Button
var last_telemetry_by_peer := {}
var telemetry_window_start := 0
var telemetry_window_count := 0
var last_ping_at_msec := 0
var last_gather_at := {}
var inventory_label: Label
var resource_label: Label
var selected_avatar := 0
var avatar_selector: OptionButton
var emote_counts := {}
var own_id := 0
var is_dedicated := false
var is_websocket_host := false
var connected_peers := {}
var updater: Node
var update_button: Button
var update_info: Label
var last_sent_position := Vector3.INF
var send_accumulator := 0.0
var fps_label: Label
var fps_accumulator := 0.0
var sprint_active := false
var client_jump_start_msec := 0
var jump_request_msec := 0
var server_jump_times := {}
var last_remote_ticks := {}
var next_footstep_at: Dictionary = {}
var footstep_variant: Dictionary = {}
var camera: Camera3D
var resource_target_marker: Node3D
var selected_resource_id := -1
var info: Label
var ip_input: LineEdit
var config_request: HTTPRequest
var discovered_host := ""
var discovered_port := PORT
var connect_mode := "lan"
var config_ready := false
var input_driver: Node
var mobile_controls: Control
var player_ui: CanvasLayer
var live_ui: Control
var legacy_ui_controls: Array[Control] = []
var sunlight: DirectionalLight3D
var ambience: Node3D
var next_ambience_at_msec := 0
var _lighting_night := false
var _lighting_tween: Tween
var foliage: Array[SphereMesh] = []
var graphics_quality := 1
var next_proximity_ui_at_msec := 0
var next_aim_hint_at_msec := 0
var performance_overlay: CanvasLayer

func _ready() -> void:
    is_dedicated = OS.get_cmdline_user_args().has("--dedicated-server")
    is_websocket_host = OS.get_cmdline_user_args().has("--websocket")
    multiplayer.peer_connected.connect(_on_join)
    multiplayer.peer_disconnected.connect(_on_leave)
    multiplayer.connected_to_server.connect(_connected)
    multiplayer.connection_failed.connect(_connection_failed)
    multiplayer.server_disconnected.connect(_server_disconnected)
    graphics_quality = GRAPHICS_SCRIPT.default_quality(is_dedicated)
    _world()
    if not is_dedicated:
        wolf_actor = WOLF_ACTOR_SCRIPT.new()
        wolf_actor.name = "Wolf"
        add_child(wolf_actor)
        wolf_actor.visible = false
    harvest_visuals = HARVEST_VFX_SCRIPT.new()
    harvest_visuals.name = "HarvestVisuals"
    add_child(harvest_visuals)
    harvest_visuals.set_combat_detail(graphics_quality == GRAPHICS_SCRIPT.HIGH)
    _load_sound_preference()
    telemetry = TELEMETRY_SCRIPT.new()
    telemetry.name = "PerformanceTelemetry"
    add_child(telemetry)
    _load_telemetry_preference()
    _reset_resources()
    GRAPHICS_SCRIPT.apply(graphics_quality, sunlight, foliage)
    get_node("Eldoria_Forest").apply_detail_quality(graphics_quality == GRAPHICS_SCRIPT.HIGH)
    if not is_dedicated:
        ambience = AMBIENCE_SCRIPT.new()
        ambience.name = "WorldAtmosphere"
        add_child(ambience)
        ambience.set_high_detail(graphics_quality == GRAPHICS_SCRIPT.HIGH)
    if not is_dedicated:
        selected_avatar = AVATAR_PROFILE.read_choice()
    input_driver = INPUT_SCRIPT.new()
    add_child(input_driver)
    if not is_dedicated:
        _ui()
        performance_overlay = OVERLAY_SCRIPT.new()
        performance_overlay.game = self
        add_child(performance_overlay)
        _init_updater()
        # Exported Windows/Android builds discover the server automatically.
        # SceneTree test harnesses supply CLI user args and trigger discovery explicitly.
        if OS.get_cmdline_user_args().is_empty():
            if DEVELOPMENT_BUILD:
                _status("Development build; connect only to your test server.")
            else:
                _fetch_server_config()
    else:
        # A separate headless Godot process can host the exact same world.
        _host()

func _world() -> void:
    var world := FOREST_SCRIPT.new()
    world.name = "Eldoria_Forest"
    add_child(world)
    sunlight = world.sun
    foliage = world.tree_leaf_meshes
    camera = Camera3D.new()
    camera.position = Vector3(0, 7, 14)
    camera.current = not is_dedicated
    camera.far = 220.0
    add_child(camera)
    camera.look_at(Vector3(0, 1, 0), Vector3.UP)
    if not is_dedicated:
        _create_resource_target_marker()

func _create_resource_target_marker() -> void:
    resource_target_marker = Node3D.new()
    resource_target_marker.name = "SelectedGatherResource"
    resource_target_marker.visible = false
    add_child(resource_target_marker)
    var ring := MeshInstance3D.new()
    ring.name = "GroundRing"
    var mesh := TorusMesh.new()
    mesh.inner_radius = 0.65
    mesh.outer_radius = 0.80
    ring.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("a9e38d",0.85)
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ring.material_override = material
    resource_target_marker.add_child(ring)
    var label := Label3D.new()
    label.name = "GatherLabel"
    label.position.y = 1.45
    label.pixel_size = 0.008
    label.font_size = 24
    label.outline_size = 6
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.modulate = Color("cff5bc")
    resource_target_marker.add_child(label)

func _ui() -> void:
    config_request = HTTPRequest.new()
    config_request.timeout = 8.0
    add_child(config_request)
    config_request.request_completed.connect(_on_config_received)
    player_ui = CanvasLayer.new()
    add_child(player_ui)
    var panel := VBoxContainer.new()
    panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
    panel.position = Vector2(24, 24)
    player_ui.add_child(panel)
    build_feedback_label = Label.new()
    build_feedback_label.text = ""
    build_feedback_label.visible = false
    build_feedback_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
    build_feedback_label.offset_left = -220
    build_feedback_label.offset_top = 105
    build_feedback_label.offset_right = 220
    build_feedback_label.offset_bottom = 160
    build_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    build_feedback_label.add_theme_font_size_override("font_size", 19)
    build_feedback_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    build_feedback_label.add_theme_constant_override("shadow_offset_x", 2)
    build_feedback_label.add_theme_constant_override("shadow_offset_y", 2)
    player_ui.add_child(build_feedback_label)
    var title := Label.new()
    title.text = "ELDORIA / CROSS-PLATFORM PRE-ALPHA"
    panel.add_child(title)
    var avatar_row := HBoxContainer.new()
    panel.add_child(avatar_row)
    var avatar_title := Label.new()
    avatar_title.text = "Hero:"
    avatar_row.add_child(avatar_title)
    avatar_selector = OptionButton.new()
    for title_text in AVATAR_PROFILE.LABELS:
        avatar_selector.add_item(title_text)
    avatar_selector.select(selected_avatar)
    avatar_selector.item_selected.connect(_choose_avatar)
    avatar_row.add_child(avatar_selector)
    # Hidden compatibility entry retained for legacy E2E and developer use.
    # Exported players never have to type a server address.
    ip_input = LineEdit.new()
    ip_input.text = "127.0.0.1"
    ip_input.placeholder_text = "Test server IP (development only)"
    ip_input.visible = DEVELOPMENT_BUILD
    panel.add_child(ip_input)
    var connect_button := Button.new()
    connect_button.text = "Join test server (DEV)" if DEVELOPMENT_BUILD else "Connect / Retry"
    connect_button.pressed.connect(_join if DEVELOPMENT_BUILD else _fetch_server_config)
    if DEVELOPMENT_BUILD:
        var host_button := Button.new()
        host_button.text = "Host test world (DEV)"
        host_button.pressed.connect(_host)
        panel.add_child(host_button)
    panel.add_child(connect_button)
    var disconnect := Button.new()
    disconnect.text = "Disconnect"
    disconnect.pressed.connect(_disconnect)
    panel.add_child(disconnect)
    var gather_button := Button.new()
    gather_button.text = "Gather (F)"
    gather_button.pressed.connect(_try_gather)
    panel.add_child(gather_button)
    var craft_button := Button.new()
    craft_button.name = "CraftAxe"
    craft_button.text = "Craft stone axe (C) — 2 wood + 2 stone; near campfire"
    craft_button.pressed.connect(_try_craft_axe)
    panel.add_child(craft_button)
    var build_row := HBoxContainer.new()
    panel.add_child(build_row)
    build_selector = OptionButton.new()
    build_selector.add_item("Campfire (3 wood, 2 stone)")
    build_selector.add_item("Tent (5 wood, 2 herbs)")
    build_row.add_child(build_selector)
    var build_button := Button.new()
    build_button.text = "Build (B)"
    build_button.pressed.connect(_try_build)
    build_row.add_child(build_button)
    var preview_button := Button.new()
    preview_button.name = "BuildPreviewToggle"
    preview_button.text = "Preview (V)"
    preview_button.pressed.connect(_toggle_build_preview)
    build_row.add_child(preview_button)
    inventory_label = Label.new()
    inventory_label.text = "Wood: 0 | Stone: 0 | Herbs: 0"
    panel.add_child(inventory_label)
    resource_label = Label.new()
    resource_label.text = "Near: none"
    panel.add_child(resource_label)
    sound_button = Button.new()
    sound_button.text = "Sound: ON" if harvest_visuals.sound_enabled else "Sound: OFF"
    sound_button.pressed.connect(_toggle_sound)
    panel.add_child(sound_button)
    telemetry_button = Button.new()
    telemetry_button.text = "Performance data: ON" if telemetry.enabled else "Performance data: OFF"
    telemetry_button.pressed.connect(_toggle_telemetry)
    panel.add_child(telemetry_button)
    var emote := Button.new()
    emote.text = "Wave (E)"
    emote.pressed.connect(_interact)
    panel.add_child(emote)
    fps_label = Label.new()
    fps_label.text = "FPS: --"
    panel.add_child(fps_label)
    info = Label.new()
    info.text = "Connecting to the online world..."
    panel.add_child(info)
    update_info = Label.new()
    update_info.text = "Checking game version..."
    panel.add_child(update_info)
    update_button = Button.new()
    update_button.text = "Install update"
    update_button.visible = false
    update_button.pressed.connect(func() -> void: updater.install_update())
    panel.add_child(update_button)

    if OS.get_name() != "Android":
        var settings := HBoxContainer.new()
        panel.add_child(settings)
        var fullscreen := Button.new()
        fullscreen.text = "Fullscreen (F11)"
        fullscreen.pressed.connect(_toggle_fullscreen)
        settings.add_child(fullscreen)
        var resolution := OptionButton.new()
        for size in DISPLAY_SCRIPT.RESOLUTIONS:
            resolution.add_item("%d x %d" % [size.x, size.y])
        resolution.select(0)
        resolution.item_selected.connect(func(index: int) -> void:
            DISPLAY_SCRIPT.set_windowed_resolution(DISPLAY_SCRIPT.RESOLUTIONS[index])
        )
        settings.add_child(resolution)

    # Responsive analogue joystick in the lower-left, not four D-pad buttons.
    mobile_controls = JOYSTICK_SCRIPT.new()
    mobile_controls.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    mobile_controls.offset_left = 20
    mobile_controls.offset_top = -222
    mobile_controls.offset_right = 218
    mobile_controls.offset_bottom = -24
    mobile_controls.visible = _mobile_ui()
    mobile_controls.moved.connect(input_driver.set_joystick)
    player_ui.add_child(mobile_controls)

    var sprint_button := Button.new()
    sprint_button.text = "Sprint: OFF"
    sprint_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    sprint_button.offset_left = -190
    sprint_button.offset_top = -225
    sprint_button.offset_right = -24
    sprint_button.offset_bottom = -169
    sprint_button.visible = _mobile_ui()
    sprint_button.pressed.connect(func() -> void:
        sprint_active = not sprint_active
        sprint_button.text = "Sprint: ON" if sprint_active else "Sprint: OFF"
    )
    player_ui.add_child(sprint_button)

    var gather_mobile := Button.new()
    gather_mobile.text = "Gather"
    gather_mobile.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    gather_mobile.offset_left = -340
    gather_mobile.offset_top = -164
    gather_mobile.offset_right = -210
    gather_mobile.offset_bottom = -100
    gather_mobile.visible = _mobile_ui()
    gather_mobile.pressed.connect(_try_gather)
    player_ui.add_child(gather_mobile)

    # One explicit construction mode instead of two tiny overlapping actions.
    mobile_build_toggle = Button.new()
    mobile_build_toggle.text = "Build mode"
    mobile_build_toggle.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    mobile_build_toggle.offset_left = -340
    mobile_build_toggle.offset_top = -240
    mobile_build_toggle.offset_right = -210
    mobile_build_toggle.offset_bottom = -177
    mobile_build_toggle.visible = _mobile_ui()
    mobile_build_toggle.pressed.connect(func() -> void: _set_mobile_build_mode(not mobile_build_mode))
    player_ui.add_child(mobile_build_toggle)

    mobile_build_panel = PanelContainer.new()
    mobile_build_panel.name = "AndroidBuildingMode"
    mobile_build_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    mobile_build_panel.offset_left = -414
    mobile_build_panel.offset_top = -390
    mobile_build_panel.offset_right = -24
    mobile_build_panel.offset_bottom = -256
    mobile_build_panel.visible = false
    player_ui.add_child(mobile_build_panel)
    var build_column := VBoxContainer.new()
    mobile_build_panel.add_child(build_column)
    var build_caption := Label.new()
    build_caption.text = "BUILD MODE — look around to move the marker"
    build_column.add_child(build_caption)
    mobile_build_picker = OptionButton.new()
    mobile_build_picker.custom_minimum_size.y = 48
    mobile_build_picker.add_item("Campfire: 3 wood + 2 stone")
    mobile_build_picker.add_item("Tent: 5 wood + 2 herbs")
    mobile_build_picker.item_selected.connect(_mobile_select_building)
    build_column.add_child(mobile_build_picker)
    var mobile_craft_button := Button.new()
    mobile_craft_button.name = "MobileCraftAxe"
    mobile_craft_button.text = "CRAFT AXE (2 wood + 2 stone)"
    mobile_craft_button.pressed.connect(_try_craft_axe)
    build_column.add_child(mobile_craft_button)
    var action_row := HBoxContainer.new()
    build_column.add_child(action_row)
    var place_button := Button.new()
    place_button.name = "MobilePlace"
    place_button.text = "PLACE"
    place_button.custom_minimum_size = Vector2(168,48)
    place_button.pressed.connect(_mobile_place_building)
    action_row.add_child(place_button)
    var cancel_button := Button.new()
    cancel_button.name = "MobileCancel"
    cancel_button.text = "CANCEL"
    cancel_button.custom_minimum_size = Vector2(168,48)
    cancel_button.pressed.connect(func() -> void: _set_mobile_build_mode(false))
    action_row.add_child(cancel_button)
    var jump_button := Button.new()
    jump_button.text = "Jump"
    jump_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    jump_button.offset_left = -340
    jump_button.offset_top = -88
    jump_button.offset_right = -210
    jump_button.offset_bottom = -24
    jump_button.visible = _mobile_ui()
    jump_button.pressed.connect(_try_jump)
    player_ui.add_child(jump_button)

    var touch_emote := Button.new()
    touch_emote.text = "Wave"
    touch_emote.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    touch_emote.offset_left = -145
    touch_emote.offset_top = -86
    touch_emote.offset_right = -24
    touch_emote.offset_bottom = -24
    touch_emote.visible = _mobile_ui()
    touch_emote.pressed.connect(_interact)
    player_ui.add_child(touch_emote)

    var quality_button := Button.new()
    quality_button.text = "Graphics: Low" if graphics_quality == GRAPHICS_SCRIPT.LOW else "Graphics: High"
    if _mobile_ui():
        quality_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
        quality_button.offset_left = -190
        quality_button.offset_top = -155
        quality_button.offset_right = -24
        quality_button.offset_bottom = -100
        player_ui.add_child(quality_button)
    else:
        panel.add_child(quality_button)
    quality_button.pressed.connect(func() -> void:
        graphics_quality = GRAPHICS_SCRIPT.HIGH if graphics_quality == GRAPHICS_SCRIPT.LOW else GRAPHICS_SCRIPT.LOW
        GRAPHICS_SCRIPT.apply(graphics_quality, sunlight, foliage)
        get_node("Eldoria_Forest").apply_detail_quality(graphics_quality == GRAPHICS_SCRIPT.HIGH)
        _apply_building_detail_quality()
        harvest_visuals.set_combat_detail(graphics_quality == GRAPHICS_SCRIPT.HIGH)
        quality_button.text = "Graphics: High" if graphics_quality == GRAPHICS_SCRIPT.HIGH else "Graphics: Low"
    )
    # Real game UI. Keep the old developer controls in the scene for tests,
    # but do not show them over the new HUD in exported builds.
    if OS.get_cmdline_user_args().is_empty() or OS.get_cmdline_user_args().has("--test-live-ui"):
        for child in player_ui.get_children():
            if child is Control and child != build_feedback_label:
                legacy_ui_controls.append(child)
                child.visible = false
        live_ui = LIVE_UI_SCRIPT.new()
        live_ui.name = "LiveUI"
        player_ui.add_child(live_ui)
        live_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        live_ui.joystick_moved.connect(input_driver.set_joystick)
        live_ui.action_requested.connect(_live_action)
        live_ui.action_requested.connect(_combat_ui_action)
        live_ui.build_requested.connect(_live_build)
        live_ui.craft_requested.connect(_try_craft_recipe)
        live_ui.equip_requested.connect(_try_equip_axe)
        live_ui.combat_equip_requested.connect(_try_equip_combat)
        live_ui.preview_requested.connect(_live_preview)
        live_ui.set_avatar(selected_avatar)
        live_ui.set_inventory(_empty_inventory())

func _init_updater() -> void:
    updater = UPDATE_SCRIPT.new()
    updater.current_version = CLIENT_VERSION
    add_child(updater)
    updater.update_available.connect(_on_update_available)
    updater.update_status.connect(_on_update_status)
    if OS.get_cmdline_user_args().is_empty() and not DEVELOPMENT_BUILD:
        updater.check_for_updates()

func _on_update_available(version: String, notes: String) -> void:
    update_info.text = "New version v%s: %s" % [version, notes]
    update_button.visible = true
    if OS.get_name() == "Android":
        update_button.text = "Download Android APK v%s" % version
    else:
        update_button.text = "Update and restart v%s" % version

func _on_update_status(message: String) -> void:
    if update_info != null:
        update_info.text = message

func _configure_world_persistence() -> bool:
    world_store = null
    persistent_profiles.clear()
    # Never write to the published game server by default. Dedicated test
    # worlds explicitly opt in with an isolated ELDORIA_SAVE_PATH.
    var api_url := OS.get_environment("ELDORIA_PG_API_URL").strip_edges()
    var file_name := OS.get_environment("ELDORIA_SAVE_PATH").strip_edges()
    if not api_url.is_empty() and not file_name.is_empty():
        push_error("Choose PostgreSQL OR legacy JSON persistence, not both")
        return false
    if api_url.is_empty() and file_name.is_empty():
        return true
    if not api_url.is_empty():
        world_store = POSTGRES_WORLD_STORE_SCRIPT.new()
        var internal_key := OS.get_environment("ELDORIA_PG_API_KEY")
        var internal_key_file := OS.get_environment("ELDORIA_PG_API_KEY_FILE")
        if internal_key.is_empty() and not internal_key_file.is_empty():
            internal_key = FileAccess.get_file_as_string(internal_key_file).strip_edges()
        if not world_store.configure(api_url, internal_key):
            push_error("Invalid PostgreSQL persistence endpoint: "+world_store.last_error)
            return false
    else:
        world_store = WORLD_SAVE_SCRIPT.new()
        if not world_store.configure(file_name):
            push_error("Cannot initialize legacy JSON save directory: "+world_store.last_error)
            return false
    var world: Node3D = get_node("Eldoria_Forest")
    if not world_store.load_snapshot(world):
        push_error("Cannot load Eldoria save: "+world_store.last_error)
        return false
    persistent_profiles = world_store.profiles.duplicate(true)
    _load_buildings(world_store.buildings)
    for id in world_store.depleted.keys():
        resource_remaining[int(id)] = int(world_store.depleted[id])
        world.set_resource_quantity(int(id),int(resource_remaining[int(id)]))
    print("ELDORIA PERSISTENCE LOADED profiles=%d depleted=%d" % [persistent_profiles.size(),world_store.depleted.size()])
    return true

func _save_world_state() -> bool:
    if world_store == null:
        return true
    world_store.profiles = persistent_profiles.duplicate(true)
    world_store.buildings = placed_buildings.duplicate(true)
    var world: Node3D = get_node("Eldoria_Forest")
    if not world_store.save_snapshot(resource_remaining,world):
        push_error("ELDORIA PERSISTENCE SAVE ERROR: "+world_store.last_error)
        return false
    return true

func _load_telemetry_preference() -> void:
    var config := ConfigFile.new()
    config.load("user://eldoria-telemetry.cfg")
    # Diagnostics are explicit and can be disabled without affecting gameplay.
    telemetry.set_enabled(bool(config.get_value("privacy","performance",true)))

func _toggle_telemetry() -> void:
    telemetry.set_enabled(not telemetry.enabled)
    var config := ConfigFile.new()
    config.set_value("privacy","performance",telemetry.enabled)
    config.save("user://eldoria-telemetry.cfg")
    if telemetry_button != null:
        telemetry_button.text = "Performance data: ON" if telemetry.enabled else "Performance data: OFF"

func _configure_telemetry_sink() -> void:
    if telemetry_sink != null:
        telemetry_sink.queue_free()
        telemetry_sink = null
    var url := OS.get_environment("ELDORIA_PG_API_URL")
    if url.is_empty():
        return
    var secret := OS.get_environment("ELDORIA_PG_API_KEY")
    var secret_file := OS.get_environment("ELDORIA_PG_API_KEY_FILE")
    if secret.is_empty() and not secret_file.is_empty():
        secret = FileAccess.get_file_as_string(secret_file).strip_edges()
    var sink := TELEMETRY_SINK_SCRIPT.new()
    sink.name = "TelemetrySink"
    add_child(sink)
    if not sink.configure(url,secret):
        push_warning("Telemetry sink unavailable; gameplay continues normally.")
        sink.queue_free()
        return
    telemetry_sink = sink

func _submit_telemetry() -> void:
    if telemetry == null or own_id == 0:
        return
    var report: Dictionary = telemetry.make_report(graphics_quality,CLIENT_VERSION)
    if report.is_empty():
        return
    if multiplayer.is_server():
        _receive_telemetry_for(own_id,report)
    elif peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
        submit_telemetry.rpc_id(1,report)

@rpc("any_peer","reliable")
func telemetry_ping(client_tick: int) -> void:
    if multiplayer.is_server():
        var sender := multiplayer.get_remote_sender_id()
        if players.has(sender):
            telemetry_pong.rpc_id(sender,client_tick)

@rpc("authority","call_remote","reliable")
func telemetry_pong(client_tick: int) -> void:
    if telemetry != null:
        var elapsed := Time.get_ticks_msec()-client_tick
        if elapsed >= 0 and elapsed <= 10000:
            telemetry.last_rtt_ms = elapsed

@rpc("any_peer","reliable")
func submit_telemetry(report: Dictionary) -> void:
    if multiplayer.is_server():
        _receive_telemetry_for(multiplayer.get_remote_sender_id(),report)

func _receive_telemetry_for(sender: int, report: Dictionary) -> bool:
    if not multiplayer.is_server() or not players.has(sender) or telemetry_sink == null:
        return false
    var now := Time.get_ticks_msec()
    if telemetry_window_start == 0 or now-telemetry_window_start >= 60000:
        telemetry_window_start = now
        telemetry_window_count = 0
    # A global guard also limits abuse via rapid reconnects.
    if telemetry_window_count >= 30:
        return false
    if last_telemetry_by_peer.has(sender) and now-int(last_telemetry_by_peer[sender]) < 45000:
        return false
    if report.size()!=9:
        return false
    if str(report.get("version",""))!=CLIENT_VERSION or str(report.get("platform","")) not in ["windows","android","test"]:
        return false
    if str(report.get("quality","")) not in ["low","high"]:
        return false
    for number in ["fps_avg","fps_low_5","frame_p95_ms"]:
        var x := float(report.get(number,0))
        if not is_finite(x) or x <= 0 or x > 2000:
            return false
    var memory_mb := int(report.get("memory_mb",-1))
    var rtt_ms := int(report.get("rtt_ms",-1))
    var samples := int(report.get("samples",-1))
    if memory_mb < 1 or memory_mb > 65536 or rtt_ms < 0 or rtt_ms > 10000 or samples < 60 or samples > 7200:
        return false
    if not telemetry_sink.enqueue(report):
        return false
    last_telemetry_by_peer[sender] = now
    telemetry_window_count += 1
    return true

func _host() -> void:
    _clear_session()
    if is_websocket_host:
        var ws_peer := WebSocketMultiplayerPeer.new()
        ws_peer.handshake_timeout = 5.0
        peer = ws_peer
        var ws_bind := OS.get_environment("ELDORIA_WS_BIND")
        if ws_bind.is_empty():
            ws_bind = "127.0.0.1"
        if ws_peer.create_server(WEBSOCKET_PORT, ws_bind) != OK:
            _status("Cannot host WebSocket TCP 7788")
            return
    else:
        var enet_peer := ENetMultiplayerPeer.new()
        peer = enet_peer
        if enet_peer.create_server(PORT, MAX_PLAYERS) != OK:
            _status("Cannot host UDP 7777")
            return
    multiplayer.multiplayer_peer = peer
    _reset_resources()
    _reset_wolf()
    raid.begin(Time.get_ticks_msec())
    raid_next_broadcast = 0
    if not _configure_world_persistence():
        push_error("Eldoria save data invalid; refusing to host")
        peer.close()
        multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
        if is_dedicated:
            get_tree().quit(1)
        return
    _configure_telemetry_sink()
    _spawn_passive_creatures()
    if is_dedicated:
        print("ELDORIA DEDICATED SERVER READY %s" % ("WS TCP 7788" if is_websocket_host else "UDP 7777"))
        return
    own_id = multiplayer.get_unique_id()
    _spawn(own_id, Vector3(0, 1, 0), selected_avatar)
    player_health[own_id] = MAX_HEALTH
    hero_mana[own_id] = HERO_CLASSES.MAGE_MANA_MAX
    player_skills[own_id] = _empty_skills()
    skill_snapshot(player_skills[own_id])
    practice_points[own_id] = 0
    practice_snapshot(0)
    health_snapshot(MAX_HEALTH, MAX_HEALTH)
    _status("Hosting UDP 7777, ID %s" % own_id)

func _join() -> void:
    # Legacy direct entry only for tests and developer tooling.
    _join_server(ip_input.text.strip_edges(), PORT)

func _join_websocket(url: String) -> void:
    if is_dedicated:
        return
    _clear_session()
    var ws_peer := WebSocketMultiplayerPeer.new()
    ws_peer.handshake_timeout = 8.0
    peer = ws_peer
    if ws_peer.create_client(url) != OK:
        _status("Unable to start secure connection. Retry.")
        return
    multiplayer.multiplayer_peer = peer
    _status("Connecting to Eldoria online world...")

func _join_server(host: String, udp_port: int) -> void:
    if is_dedicated:
        return
    _clear_session()
    peer = ENetMultiplayerPeer.new()
    if peer.create_client(host, udp_port) != OK:
        _status("Cannot connect to %s:%d" % [host, udp_port])
        return
    multiplayer.multiplayer_peer = peer
    _status("Connecting to Eldoria server %s:%d (%s)..." % [host, udp_port, connect_mode])

func _fetch_server_config() -> void:
    if is_dedicated or config_request == null:
        return
    config_ready = false
    var endpoint := SERVER_CONFIG_URL
    var test_endpoint := OS.get_environment("ELDORIA_CONFIG_URL")
    if not test_endpoint.is_empty():
        endpoint = test_endpoint
    if DEVELOPMENT_BUILD and endpoint == SERVER_CONFIG_URL:
        _status("DEV protocol: production matchmaking disabled.")
        return
    config_request.cancel_request()
    _status("Finding Eldoria server...")
    var result := config_request.request(endpoint, ["Cache-Control: no-cache"])
    if result != OK:
        _status("Cannot fetch Eldoria server configuration (error %d). Retry." % result)

func _on_config_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
    if result != HTTPRequest.RESULT_SUCCESS or response_code != 200 or body.size() > 4096:
        _status("Server lookup failed (HTTP %d). Check Internet and retry." % response_code)
        return
    var json := JSON.new()
    if json.parse(body.get_string_from_utf8()) != OK or not json.data is Dictionary:
        _status("Invalid server configuration. Retry.")
        return
    var data: Dictionary = json.data
    var address := String(data.get("host", ""))
    var port_value := int(data.get("port", 0))
    var protocol := String(data.get("protocol", ""))
    var status := String(data.get("status", ""))
    if int(data.get("schema", -1)) != 1 or (protocol != "godot-enet" and protocol != "godot-websocket"):
        _status("Unsupported Eldoria server configuration.")
        return
    if protocol == "godot-enet" and (port_value < 1 or port_value > 65535):
        _status("Unsupported Eldoria server configuration.")
        return
    if protocol == "godot-enet" and (address.is_empty() or address.length() > 253 or address.contains("/") or address.contains(":") or address.contains(" ")):
        _status("Invalid server address in configuration.")
        return
    if protocol == "godot-enet" and not address.is_valid_ip_address() and not _is_valid_host_name(address):
        _status("Invalid server hostname in configuration.")
        return
    if String(data.get("client_version", "")) != CLIENT_VERSION:
        _status("Please update Eldoria client to v%s." % String(data.get("client_version", "?")))
        return
    if status != "lan" and status != "public":
        _status("Eldoria server is unavailable. Retry later.")
        return
    connect_mode = status
    if protocol == "godot-websocket":
        var websocket_url := String(data.get("url", ""))
        var allow_local_test := not OS.get_environment("ELDORIA_CONFIG_URL").is_empty()
        if websocket_url != "wss://bacus.dev/eldoria/ws" and not (allow_local_test and websocket_url.begins_with("ws://127.0.0.1:")):
            _status("Untrusted WebSocket endpoint in server configuration.")
            return
        discovered_host = websocket_url
        discovered_port = 443
        config_ready = true
        print("ELDORIA CONFIG READY %s (public)" % websocket_url)
        _join_websocket(websocket_url)
    else:
        discovered_host = address
        discovered_port = port_value
        config_ready = true
        print("ELDORIA CONFIG READY %s:%d (%s)" % [address, port_value, status])
        _join_server(address, port_value)

func _is_valid_host_name(value: String) -> bool:
    # No URL syntax, injection or arbitrary text; only hostname tokens.
    for c in value:
        if not "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-".contains(c):
            return false
    return not value.begins_with(".") and not value.ends_with(".")

func _connected() -> void:
    own_id = multiplayer.get_unique_id()
    var identity := OS.get_environment("ELDORIA_TEST_IDENTITY")
    if identity.is_empty() and OS.get_cmdline_user_args().is_empty():
        identity = AVATAR_PROFILE.read_token()
    request_spawn.rpc_id(1, selected_avatar, identity)
    if telemetry != null:
        telemetry.set_enabled(telemetry.enabled)
    _status("Connected, ID %s" % own_id)

func _on_join(id: int) -> void:
    if multiplayer.is_server():
        if connected_peers.size() >= MAX_PLAYERS:
            multiplayer.multiplayer_peer.disconnect_peer(id)
            return
        connected_peers[id] = true
        print("ELDORIA PEER CONNECTED %d" % id)
        _status("Player %s connected" % id)

func _on_leave(id: int) -> void:
    connected_peers.erase(id)
    last_telemetry_by_peer.erase(id)
    player_identity_keys.erase(id)
    healing_cooldowns.erase(id)
    player_skills.erase(id)
    shield_taunt_until.erase(id)
    shield_taunt_ready_at.erase(id)
    training_last_hit.erase(id)
    _remove_actor(id)
    # SceneMultiplayer propagates peer_disconnected to all clients already.
    # No extra RPC: a peer may have closed its ENet channel during this signal.

@rpc("authority", "call_remote", "reliable")
func despawn_remote(id: int) -> void:
    _remove_actor(id)

func _remove_actor(id: int) -> void:
    player_health.erase(id)
    hero_ability_ready_at.erase(id)
    hero_mana.erase(id)
    player_respawn_at.erase(id)
    last_attack_at.erase(id)
    equipped_axes.erase(id)
    equipped_combat.erase(id)
    if players.has(id):
        players[id].queue_free()
        players.erase(id)
    emote_counts.erase(id)
    player_choices.erase(id)
    player_inventories.erase(id)
    practice_points.erase(id)
    player_skills.erase(id)
    shield_taunt_until.erase(id)
    shield_taunt_ready_at.erase(id)
    training_last_hit.erase(id)
    last_gather_at.erase(id)
    last_remote_ticks.erase(id)
    next_footstep_at.erase(id)
    footstep_variant.erase(id)
    server_jump_times.erase(id)

func _clear_session() -> void:
    own_id = 0
    if ambience != null:
        ambience.clear()
    next_footstep_at.clear()
    footstep_variant.clear()
    player_health.clear()
    player_respawn_at.clear()
    last_attack_at.clear()
    wolf_alive = false
    pack_wolves.clear()
    for actor in pack_actors.values():
        actor.queue_free()
    pack_actors.clear()
    raid.begin(0)
    healing_cooldowns.clear()
    if wolf_actor != null:
        wolf_actor.visible = false
    equipped_axes.clear()
    equipped_combat.clear()
    passive_creatures.clear()
    practice_points.clear()
    player_skills.clear()
    shield_taunt_until.clear()
    shield_taunt_ready_at.clear()
    hero_ability_ready_at.clear()
    hero_mana.clear()
    training_last_hit.clear()
    for actor in passive_actors.values():
        if is_instance_valid(actor):
            actor.queue_free()
    passive_actors.clear()
    if live_ui != null:
        live_ui.reset_health()
        live_ui.set_equipped_axe(false)
        live_ui.set_combat_equipment("unarmed")
        live_ui.set_practice_points(0)
        live_ui.set_skills(_empty_skills())
        live_ui.set_inventory(_empty_inventory())
        live_ui.set_near_campfire(false)
    last_ping_at_msec = 0
    if telemetry != null:
        telemetry.set_enabled(telemetry.enabled)
    last_sent_position = Vector3.INF
    send_accumulator = 0.0
    connected_peers.clear()
    _remove_preview()
    mobile_build_mode = false
    if mobile_build_panel != null:
        mobile_build_panel.visible = false
    if harvest_visuals != null:
        harvest_visuals.clear_effects()
    last_remote_ticks.clear()
    player_choices.clear()
    _clear_buildings()
    player_inventories.clear()
    player_identity_keys.clear()
    last_gather_at.clear()
    server_jump_times.clear()
    client_jump_start_msec = 0
    jump_request_msec = 0
    if mobile_controls != null and mobile_controls.has_method("reset"):
        mobile_controls.reset()
    if input_driver != null:
        input_driver.clear_touch()
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    peer.close()
    for id in players.keys():
        _remove_actor(id)

func _disconnect() -> void:
    if is_dedicated:
        return
    _clear_session()
    _status("Disconnected. Host or join to play.")

func _connection_failed() -> void:
    _clear_session()
    _status("Cannot reach Eldoria game server. On LAN, use the same Wi-Fi. Retry.")

func _server_disconnected() -> void:
    _clear_session()
    _status("Server disconnected")

func _status(message: String) -> void:
    if info != null:
        info.text = message
    if live_ui != null:
        live_ui.set_status(message)

@rpc("any_peer", "reliable")
func request_spawn(choice: int = 0, identity_token: String = "") -> void:
    if not multiplayer.is_server():
        return
    var id := multiplayer.get_remote_sender_id()
    if players.has(id):
        return
    var validated: int = AVATAR_PROFILE.normalized(choice)
    var identity_hash := ""
    if AVATAR_PROFILE.valid_token(identity_token):
        identity_hash = identity_token.sha256_text()
        if identity_hash in player_identity_keys.values():
            # A single credential must not control two connected characters.
            multiplayer.multiplayer_peer.disconnect_peer(id)
            return
        player_identity_keys[id] = identity_hash
        var existing_profile: Dictionary = persistent_profiles.get(identity_hash,{})
        if not existing_profile.is_empty():
            validated = AVATAR_PROFILE.normalized(int(existing_profile.get("avatar",validated)))
    # Persist a new identity BEFORE making it visible to other players.
    # Do not let an unavailable DB silently spawn an unsaved online player.
    if not identity_hash.is_empty() and not persistent_profiles.has(identity_hash):
        persistent_profiles[identity_hash] = {"avatar":validated,"inventory":_empty_inventory(),"skills":_empty_skills()}
        if not _save_world_state():
            persistent_profiles.erase(identity_hash)
            player_identity_keys.erase(id)
            multiplayer.multiplayer_peer.disconnect_peer(id)
            return
    for existing in players:
        spawn_remote.rpc_id(id, existing, players[existing].position, int(player_choices.get(existing, 0)))
        # Late joiners see authoritative equipment on existing remote players.
        axe_visual_snapshot.rpc_id(id, int(existing), bool(equipped_axes.get(existing, false)))
        combat_visual_snapshot.rpc_id(id, int(existing), str(equipped_combat.get(existing,"unarmed")))
        var remaining_taunt := int(shield_taunt_until.get(existing,0)) - Time.get_ticks_msec()
        if remaining_taunt > 0:
            shield_taunt_visual.rpc_id(id,int(existing),mini(remaining_taunt,SHIELD_TAUNT_DURATION_MS))
    var pos := Vector3(float(players.size() * 3), 1, 0)
    _spawn(id, pos, validated)
    player_health[id] = MAX_HEALTH
    hero_mana[id] = HERO_CLASSES.MAGE_MANA_MAX
    player_inventories[id] = _empty_inventory()
    player_skills[id] = _empty_skills()
    practice_points[id] = 0
    equipped_axes[id] = false
    equipped_combat[id] = "unarmed"
    if not identity_hash.is_empty() and persistent_profiles.has(identity_hash):
        player_inventories[id] = persistent_profiles[identity_hash]["inventory"].duplicate(true)
        player_skills[id] = persistent_profiles[identity_hash].get("skills",_empty_skills()).duplicate(true)
    spawn_remote.rpc(id, pos, validated)
    resource_snapshot.rpc_id(id, resource_remaining)
    inventory_snapshot.rpc_id(id, player_inventories[id])
    axe_equip_snapshot.rpc_id(id, false)
    health_snapshot.rpc_id(id, MAX_HEALTH, MAX_HEALTH)
    practice_snapshot.rpc_id(id, int(practice_points[id]))
    skill_snapshot.rpc_id(id,player_skills[id])
    mana_snapshot.rpc_id(id, int(hero_mana[id]))
    for existing_id in players:
        if int(existing_id) != id:
            health_snapshot_for.rpc_id(id, int(existing_id), int(player_health.get(existing_id, MAX_HEALTH)))
    health_snapshot_for.rpc(id, MAX_HEALTH)
    wolf_snapshot.rpc_id(id, wolf_position, wolf_health, wolf_alive, wolf_direction)
    camp_health_snapshot.rpc_id(id, camp_hp, CAMP_MAX_HP)
    for pack_id in pack_wolves:
        var enemy: Dictionary = pack_wolves[pack_id]
        pack_wolf_snapshot.rpc_id(id, int(pack_id), enemy["position"], int(enemy["hp"]), bool(enemy["alive"]), enemy["direction"])
    for creature_id in passive_creatures:
        var animal: Dictionary = passive_creatures[creature_id]
        passive_snapshot.rpc_id(id, int(creature_id), animal["species"], animal["position"], int(animal["hp"]), bool(animal["alive"]), animal["direction"])
    raid_state.rpc_id(id, raid.snapshot(Time.get_ticks_msec()))
    building_snapshot.rpc_id(id, placed_buildings)

@rpc("authority", "call_remote", "reliable")
func spawn_remote(id: int, pos: Vector3, choice: int = 0) -> void:
    _spawn(id, pos, choice)

func _spawn(id: int, pos: Vector3, choice: int = -1) -> void:
    if players.has(id):
        return
    var valid_choice: int = choice if AVATAR_PROFILE.valid(choice) else posmod(id, AVATAR_PROFILE.NAMES.size())
    var actor := ACTOR_SCRIPT.new()
    actor.configure(id, is_dedicated, valid_choice)
    actor.name = "Player_%s" % id
    actor.position = pos
    add_child(actor)
    players[id] = actor
    player_choices[id] = valid_choice
    if id == own_id and not is_dedicated:
        selected_avatar = valid_choice
        if live_ui != null:
            live_ui.set_avatar(valid_choice)
            live_ui.set_hero_class(valid_choice)
        if avatar_selector != null:
            avatar_selector.select(valid_choice)
        if OS.get_cmdline_user_args().is_empty():
            AVATAR_PROFILE.save_choice(valid_choice)
    emote_counts[id] = 0

func _choose_avatar(choice: int) -> void:
    if not AVATAR_PROFILE.valid(choice):
        return
    if own_id == 0:
        selected_avatar = choice
        if live_ui != null:
            live_ui.set_avatar(choice)
        if AVATAR_PROFILE.save_choice(choice) != OK:
            _status("Could not save avatar preference.")
        return
    if multiplayer.is_server():
        if _change_hero_on_server(own_id, choice):
            for remote_peer in connected_peers.keys():
                avatar_changed.rpc_id(int(remote_peer), own_id, choice)
    else:
        request_avatar_change.rpc_id(1, choice)

@rpc("any_peer", "reliable")
func request_avatar_change(choice: int) -> void:
    if not multiplayer.is_server() or not AVATAR_PROFILE.valid(choice):
        return
    var peer_id := multiplayer.get_remote_sender_id()
    if not players.has(peer_id):
        return
    if _change_hero_on_server(peer_id, choice):
        avatar_changed.rpc(peer_id, choice)

@rpc("authority", "call_remote", "reliable")
func avatar_changed(id: int, choice: int) -> void:
    _set_avatar_for_peer(id, choice)

func _set_avatar_for_peer(id: int, choice: int) -> bool:
    if not players.has(id) or not AVATAR_PROFILE.valid(choice):
        return false
    if multiplayer.is_server() and player_identity_keys.has(id):
        var key: String = player_identity_keys[id]
        if persistent_profiles.has(key):
            var previous: int = int(persistent_profiles[key]["avatar"])
            if previous != choice:
                persistent_profiles[key]["avatar"] = choice
                if not _save_world_state():
                    persistent_profiles[key]["avatar"] = previous
                    return false
    player_choices[id] = choice
    players[id].set_avatar(choice)
    if id == own_id:
        selected_avatar = choice
    if id == own_id and avatar_selector != null:
        avatar_selector.select(choice)
    if id == own_id and live_ui != null:
        live_ui.set_avatar(choice)
        live_ui.set_hero_class(choice)
    if id == own_id and not is_dedicated and OS.get_cmdline_user_args().is_empty():
        AVATAR_PROFILE.save_choice(choice)
    return true

func _change_hero_on_server(id: int, choice: int) -> bool:
    if not multiplayer.is_server() or not players.has(id) or not AVATAR_PROFILE.valid(choice):
        return false
    if choice == int(player_choices[id]):
        return true
    if int(player_health.get(id,0)) <= 0 or not _near_campfire(id):
        _send_hero_message(id,"Сменить героя можно только возле костра")
        return false
    if not _set_avatar_for_peer(id,choice):
        _send_hero_message(id,"Не удалось сохранить смену героя")
        return false
    shield_taunt_until.erase(id)
    hero_ability_ready_at.erase(id)
    if choice == HERO_CLASSES.MAGE:
        hero_mana[id] = HERO_CLASSES.MAGE_MANA_MAX
        _send_mana_snapshot(id)
    _send_hero_message(id,"Класс: " + HERO_CLASSES.class_description(choice))
    return true

func _send_hero_message(id: int, message: String) -> void:
    if id == own_id:
        hero_message(message)
    elif multiplayer.get_peers().has(id):
        hero_message.rpc_id(id,message)

@rpc("authority","call_remote","reliable")
func hero_message(message: String) -> void:
    if live_ui != null:
        live_ui.show_message(message)


func _physics_process(delta: float) -> void:
    if multiplayer.is_server():
        _combat_server_tick(delta)
    if live_ui != null and not live_ui.active_panel.is_empty():
        return
    if own_id != 0 and int(player_health.get(own_id, MAX_HEALTH)) <= 0:
        return
    if is_dedicated or own_id == 0 or not players.has(own_id):
        return
    if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
        return
    var axis: Vector2 = input_driver.get_move_vector()
    var fast := sprint_active or Input.is_key_pressed(KEY_SHIFT)
    var speed := MOVE_SPEED * (1.5 if fast else 1.0)
    if int(player_choices.get(own_id,-1)) == HERO_CLASSES.ROGUE:
        speed *= HERO_CLASSES.ROGUE_SPEED_MULTIPLIER
    var delta_pos := Vector3(axis.x, 0, axis.y).rotated(Vector3.UP, input_driver.yaw) * speed * delta
    var world: Node3D = get_node("Eldoria_Forest")
    var before: Vector3 = players[own_id].position
    var after: Vector3 = world.move_actor(before, delta_pos)
    if client_jump_start_msec > 0:
        var elapsed := float(Time.get_ticks_msec()-client_jump_start_msec)/1000.0
        if elapsed >= JUMP_MOTION.DURATION:
            client_jump_start_msec = 0
            players[own_id].finish_jump()
        else:
            after.y += JUMP_MOTION.elevation(elapsed)
    players[own_id].position = after
    players[own_id].set_motion((after-before)/maxf(delta,0.001),fast)
    _play_movement_audio(own_id,after-before,fast)
    var focus: Vector3 = players[own_id].position + Vector3(0, 1.6, 0)
    var zoom: float = input_driver.camera_distance
    var offset := Vector3(0, -sin(input_driver.pitch) * zoom, cos(input_driver.pitch) * zoom)
    var target: Vector3 = focus + offset.rotated(Vector3.UP, input_driver.yaw)
    var smoothed: Vector3 = camera.position.lerp(target, minf(1.0, delta * 7.0))
    camera.position = world.camera_safe_target(focus, smoothed)
    camera.look_at(focus, Vector3.UP)
    if live_ui != null and ["bow","spear"].has(live_ui.combat_equipment):
        var from: Vector3 = players[own_id].position + Vector3.UP*0.8
        var direction: Vector3 = _bow_aim_direction()
        var projection: Vector3 = from + direction * (12.0 if live_ui.combat_equipment == "bow" else 4.5)
        if not camera.is_position_behind(projection):
            live_ui.set_combat_reticle(camera.unproject_position(projection))
        if Time.get_ticks_msec() >= next_aim_hint_at_msec:
            next_aim_hint_at_msec = Time.get_ticks_msec() + 125
            live_ui.set_combat_target_status(
                _bow_reticle_state(from,direction) if live_ui.combat_equipment == "bow"
                else _spear_reticle_state(players[own_id].position,direction))
    send_accumulator += delta
    var at: Vector3 = players[own_id].position
    if send_accumulator >= 0.05:
        send_accumulator = fmod(send_accumulator,0.05)
        if at.distance_squared_to(last_sent_position) > 0.00004:
            if multiplayer.is_server():
                sync_position.rpc(own_id, at)
            else:
                submit_position.rpc_id(1, at)
            last_sent_position = at

func _process(delta: float) -> void:
    # UI-only proximity hints don't need full-frame broadphase queries and
    # legacy label formatting. Craft/build requests still validate immediately
    # on the authoritative server, so this never changes gameplay rules.
    var ui_now := Time.get_ticks_msec()
    if ambience != null and own_id > 0 and players.has(own_id) and ui_now >= next_ambience_at_msec:
        next_ambience_at_msec = ui_now+450
        ambience.update_campfires(building_nodes,players[own_id].position)
    if ui_now >= next_proximity_ui_at_msec:
        next_proximity_ui_at_msec = ui_now + 200
        if live_ui != null:
            live_ui.set_near_campfire(own_id != 0 and _near_campfire(own_id))
        _refresh_gather_hud()
    if not is_dedicated and telemetry != null and own_id != 0 and players.has(own_id):
        telemetry.sample_frame(delta)
        if Time.get_ticks_msec() - last_ping_at_msec > 15000 and last_ping_at_msec > 0:
            last_ping_at_msec = Time.get_ticks_msec()
            if not multiplayer.is_server():
                telemetry_ping.rpc_id(1,last_ping_at_msec)
        elif last_ping_at_msec == 0:
            last_ping_at_msec = Time.get_ticks_msec()
        if telemetry.ready_to_report():
            _submit_telemetry()
    if fps_label == null:
        return
    fps_accumulator += delta
    if fps_accumulator >= 0.65:
        fps_accumulator = 0.0
        fps_label.text = "FPS: %d | %s" % [Engine.get_frames_per_second(), "Low" if graphics_quality == GRAPHICS_SCRIPT.LOW else "High"]
    if preview_enabled and not is_dedicated and Time.get_ticks_msec()-preview_last_update_msec >= 260:
        _update_build_preview()
    if build_feedback_label != null and build_feedback_label.visible and Time.get_ticks_msec() > build_feedback_until:
        build_feedback_label.visible = false

@rpc("any_peer", "unreliable")
func submit_position(pos: Vector3) -> void:
    if not multiplayer.is_server():
        return
    var id := multiplayer.get_remote_sender_id()
    if not players.has(id):
        return
    if int(player_health.get(id, MAX_HEALTH)) <= 0:
        correct_own_position.rpc_id(id, players[id].position)
        return
    # The same deterministic obstacle layout runs on the dedicated server.
    # Reject tunneling across tree trunks/rocks and impossible terrain height.
    var world: Node3D = get_node("Eldoria_Forest")
    var allowed_jump := 0.0
    if server_jump_times.has(id):
        var elapsed: float = float(Time.get_ticks_msec()-int(server_jump_times[id]))/1000.0
        if elapsed < JUMP_MOTION.DURATION + 0.25:
            allowed_jump = JUMP_MOTION.elevation(elapsed)
        else:
            server_jump_times.erase(id)
    if not world.valid_remote_step(players[id].position,pos,0.43,allowed_jump):
        correct_own_position.rpc_id(id,players[id].position)
        return
    var before: Vector3 = players[id].position
    players[id].position = pos
    _note_remote_motion(id,before,pos)
    sync_position.rpc(id, pos)

@rpc("authority", "call_remote", "reliable")
func correct_own_position(pos: Vector3) -> void:
    if own_id != 0 and players.has(own_id):
        players[own_id].position = pos
        last_sent_position = pos

@rpc("authority", "call_remote", "unreliable")
func sync_position(id: int, pos: Vector3) -> void:
    if id == own_id or not players.has(id):
        return
    var before: Vector3 = players[id].position
    players[id].position = pos
    _note_remote_motion(id,before,pos)

func _note_remote_motion(id: int, before: Vector3, after: Vector3) -> void:
    if not players.has(id):
        return
    var now := Time.get_ticks_msec()
    var prev := int(last_remote_ticks.get(id,now-50))
    last_remote_ticks[id] = now
    var elapsed := maxf(0.02,float(now-prev)/1000.0)
    players[id].set_motion((after-before)/elapsed)
    _play_movement_audio(id,after-before,false)
    if players[id].airborne and int(Time.get_ticks_msec()-int(players[id].get_meta("jump_start_msec",0))) > int(JUMP_MOTION.DURATION*1000.0):
        players[id].finish_jump()

func _play_movement_audio(id: int, delta_position: Vector3, running: bool) -> void:
    if is_dedicated or harvest_visuals == null or not players.has(id) or players[id].airborne:
        return
    if Vector2(delta_position.x,delta_position.z).length_squared() < 0.0009:
        return
    var now := Time.get_ticks_msec()
    if now < int(next_footstep_at.get(id,0)):
        return
    var side := int(footstep_variant.get(id,0))
    if harvest_visuals.play_sound("step_a" if side % 2 == 0 else "step_b",players[id].position):
        footstep_variant[id] = side+1
        next_footstep_at[id] = now + (320 if running else 460)

# TASK-025: one server-owned enemy and non-persistent session health.
# Client RPCs carry no damage or target coordinates. Distance, cooldown,
# ownership and actual HP are validated exclusively on the host.
func _reset_wolf() -> void:
    var world: Node3D = get_node("Eldoria_Forest")
    wolf_position = Vector3(WOLF_SPAWN.x, world.height_at(WOLF_SPAWN.x, WOLF_SPAWN.z) + 0.1, WOLF_SPAWN.z)
    wolf_health = WOLF_MAX_HEALTH
    wolf_alive = true
    wolf_respawn_at = 0
    wolf_last_hit_at = 0
    wolf_sync_timer = 0.0
    wolf_direction = Vector3.ZERO

func _raid_server_tick(now: int) -> void:
    var transition: String = raid.advance(now)
    if transition == "night_started":
        raid_anchor = Vector3.ZERO
        camp_hp = CAMP_MAX_HP
        camp_target_id = 0
        for record in placed_buildings.values():
            if str(record.get("kind", "")) == "campfire":
                raid_anchor = Vector3(float(record["x"]), 0, float(record["z"]))
                break
        for building_id in placed_buildings:
            if str(placed_buildings[building_id].get("kind", "")) == "campfire":
                camp_target_id = int(building_id)
                break
        camp_health_snapshot.rpc(camp_hp, CAMP_MAX_HP)
        _spawn_raid_wolf()
        _spawn_raid_pack()
        _broadcast_raid_state(now)
    elif transition != "":
        _clear_raid_pack()
        _broadcast_raid_state(now)
    if raid.phase == "night" and not wolf_alive and wolf_respawn_at > 0 and now >= wolf_respawn_at:
        _spawn_raid_wolf()
    if now >= raid_next_broadcast:
        raid_next_broadcast = now + 1000
        _broadcast_raid_state(now)

func _spawn_raid_wolf() -> void:
    var world: Node3D = get_node("Eldoria_Forest")
    var angle := float(raid.kills % 4) * PI * 0.5 + PI * 0.25
    var spawn := raid_anchor + Vector3(cos(angle) * 8.5, 0, sin(angle) * 8.5)
    _reset_wolf()
    wolf_position = Vector3(spawn.x, world.height_at(spawn.x, spawn.z) + 0.1, spawn.z)
    wolf_snapshot.rpc(wolf_position, wolf_health, true, Vector3.ZERO)

func _spawn_raid_pack() -> void:
    _clear_raid_pack()
    var world: Node3D = get_node("Eldoria_Forest")
    for pack_id in range(1, 3):
        var angle := float(pack_id) * TAU / 3.0 + PI * 0.25
        var at := raid_anchor + Vector3(cos(angle) * 9.0, 0, sin(angle) * 9.0)
        at.y = world.height_at(at.x, at.z) + 0.1
        pack_wolves[pack_id] = {"position": at, "hp": WOLF_MAX_HEALTH, "alive": true, "direction": Vector3.ZERO, "last_hit": 0}
        pack_wolf_snapshot.rpc(pack_id, at, WOLF_MAX_HEALTH, true, Vector3.ZERO)

func _clear_raid_pack() -> void:
    for pack_id in pack_wolves:
        var enemy: Dictionary = pack_wolves[pack_id]
        pack_wolf_snapshot.rpc(int(pack_id), enemy["position"], 0, false, Vector3.ZERO)
    pack_wolves.clear()

@rpc("authority", "call_remote", "reliable")
func pack_wolf_snapshot(pack_id: int, at: Vector3, hp: int, alive: bool, direction: Vector3) -> void:
    if pack_id < 1 or pack_id > 2 or not at.is_finite() or at.length() > 5000 or is_dedicated:
        return
    if not pack_actors.has(pack_id) and alive:
        var actor: Node3D = WOLF_ACTOR_SCRIPT.new()
        actor.name = "RaidWolf%d" % pack_id
        add_child(actor)
        pack_actors[pack_id] = actor
    if pack_actors.has(pack_id):
        if not alive and pack_actors[pack_id].initialized and not pack_actors[pack_id].down and harvest_visuals != null:
            harvest_visuals.play_sound("wolf_death",at)
        pack_actors[pack_id].update_state(at, clampi(hp, 0, WOLF_MAX_HEALTH), alive, direction)

@rpc("authority", "call_remote", "reliable")
func camp_health_snapshot(hp: int, maximum: int) -> void:
    camp_hp = clampi(hp, 0, maximum)
    if live_ui != null:
        live_ui.set_camp_health(camp_hp, maximum)

func _damage_camp(amount: int, now: int, enemy_id: int) -> bool:
    if not multiplayer.is_server() or raid.phase != "night" or camp_target_id == 0 or amount <= 0 or camp_hp <= 0:
        return false
    if now-int(camp_last_hit.get(enemy_id, now-1800)) < 1800:
        return false
    camp_last_hit[enemy_id] = now
    camp_hp = maxi(0, camp_hp-amount)
    camp_health_snapshot.rpc(camp_hp, CAMP_MAX_HP)
    if camp_hp == 0 and raid.camp_destroyed(now) == "camp_lost":
        wolf_alive = false
        wolf_snapshot.rpc(wolf_position, 0, false, Vector3.ZERO)
        _broadcast_raid_state(now)
    return true

@rpc("any_peer", "reliable")
func request_camp_repair() -> void:
    if multiplayer.is_server():
        _repair_camp_on_server(multiplayer.get_remote_sender_id())

func _repair_camp_on_server(id: int) -> bool:
    if not multiplayer.is_server() or raid.phase != "night" or camp_target_id == 0 or not players.has(id) or int(player_health.get(id, 0)) <= 0:
        return false
    if camp_hp <= 0 or camp_hp >= CAMP_MAX_HP or not _near_campfire(id):
        return false
    var now := Time.get_ticks_msec()
    if now-int(repair_cooldowns.get(id, now-2000)) < 2000:
        return false
    var old_inv: Dictionary = player_inventories.get(id, _empty_inventory()).duplicate(true)
    if int(old_inv.get("wood",0)) < 2 or int(old_inv.get("stone",0)) < 1:
        return false
    var inv := old_inv.duplicate(true)
    inv["wood"] = int(inv["wood"])-2
    inv["stone"] = int(inv["stone"])-1
    player_inventories[id] = inv
    if player_identity_keys.has(id):
        persistent_profiles[player_identity_keys[id]]["inventory"] = inv.duplicate(true)
    if not _save_world_state():
        player_inventories[id] = old_inv
        if player_identity_keys.has(id):
            persistent_profiles[player_identity_keys[id]]["inventory"] = old_inv.duplicate(true)
        return false
    repair_cooldowns[id] = now
    camp_hp = mini(CAMP_MAX_HP, camp_hp+30)
    camp_health_snapshot.rpc(camp_hp, CAMP_MAX_HP)
    if id == own_id:
        inventory_snapshot(inv)
    else:
        inventory_snapshot.rpc_id(id, inv)
    return true

func _broadcast_raid_state(now: int) -> void:
    var status: Dictionary = raid.snapshot(now)
    raid_state.rpc(status)
    if own_id != 0:
        raid_state(status)

@rpc("authority", "call_remote", "reliable")
func raid_state(status: Dictionary) -> void:
    if not ["prepare", "night", "intermission"].has(str(status.get("phase", ""))):
        return
    var round_number := clampi(int(status.get("round", 1)), 1, 10000)
    var kills := clampi(int(status.get("kills", 0)), 0, 4)
    var goal := clampi(int(status.get("goal", 4)), 1, 4)
    var remaining := clampi(int(status.get("seconds", 0)), 0, 3600)
    if live_ui != null:
        live_ui.set_raid_status(str(status["phase"]), round_number, kills, goal, remaining)
    _apply_raid_lighting(str(status["phase"]))

func _apply_raid_lighting(phase: String) -> void:
    if sunlight == null or is_dedicated:
        return
    var night := phase == "night"
    if night == _lighting_night:
        return
    _lighting_night = night
    if ambience != null:
        ambience.set_night(night)
    if _lighting_tween != null and _lighting_tween.is_running():
        _lighting_tween.kill()
    var forest: Node3D = get_node("Eldoria_Forest")
    if forest.environment_node != null:
        var environment: Environment = forest.environment_node.environment
        _lighting_tween = create_tween().set_parallel(true)
        _lighting_tween.tween_property(sunlight,"light_energy",0.29 if night else 0.82,1.15)
        _lighting_tween.tween_property(sunlight,"light_color",Color("9eafd6") if night else Color("ffdda8"),1.15)
        _lighting_tween.tween_property(environment,"ambient_light_color",Color("6e84ac") if night else Color("a9bfd0"),1.15)
        _lighting_tween.tween_property(environment,"ambient_light_energy",0.21 if night else 0.48,1.15)
        _lighting_tween.tween_property(environment,"fog_density",0.0036 if night else 0.0016,1.15)
        _lighting_tween.tween_property(environment,"fog_light_color",Color("61799f") if night else Color("afc6d5"),1.15)
        var sky_mat := environment.sky.sky_material as ShaderMaterial
        if sky_mat != null:
            var stored_mix: Variant = sky_mat.get_shader_parameter("night_mix")
            var previous: float = float(stored_mix) if stored_mix != null else 0.0
            _lighting_tween.tween_method(func(mix: float) -> void:
                sky_mat.set_shader_parameter("night_mix",mix),previous,1.0 if night else 0.0,1.15)

func _reward_raid_survivors() -> void:
    # Reward only living connected players. Persist everyone's reward as one
    # snapshot; if persistence fails, roll back every in-memory inventory.
    var old_inventories := player_inventories.duplicate(true)
    var old_profiles := persistent_profiles.duplicate(true)
    var recipients: Array[int] = []
    for player_id in players.keys():
        var id := int(player_id)
        if int(player_health.get(id, 0)) <= 0:
            continue
        var inv: Dictionary = player_inventories.get(id, _empty_inventory()).duplicate(true)
        inv["herb"] = int(inv.get("herb", 0)) + 2
        inv["stone"] = int(inv.get("stone", 0)) + 2
        player_inventories[id] = inv
        if player_identity_keys.has(id):
            var key: String = player_identity_keys[id]
            persistent_profiles[key]["inventory"] = inv.duplicate(true)
        recipients.append(id)
    if not _save_world_state():
        player_inventories = old_inventories
        persistent_profiles = old_profiles
        push_warning("Raid reward not saved; refusing to acknowledge unpersisted loot.")
        return
    for id in recipients:
        if id == own_id:
            inventory_snapshot(player_inventories[id])
            if live_ui != null:
                live_ui.show_message("Лагерь защищён! +2 камня и +2 травы")
        else:
            inventory_snapshot.rpc_id(id, player_inventories[id])
            raid_reward.rpc_id(id, 2, 2)

@rpc("authority", "call_remote", "reliable")
func raid_reward(stone: int, herb: int) -> void:
    if live_ui != null and stone == 2 and herb == 2:
        live_ui.show_message("Победа! +2 камня и +2 травы")

func _try_heal_at_camp() -> void:
    if own_id == 0 or not players.has(own_id):
        return
    if multiplayer.is_server():
        _heal_on_server(own_id)
    else:
        request_camp_heal.rpc_id(1)

func _try_repair_camp() -> void:
    if own_id <= 0:
        return
    if multiplayer.is_server():
        _repair_camp_on_server(own_id)
    else:
        request_camp_repair.rpc_id(1)

@rpc("any_peer", "reliable")
func request_camp_heal() -> void:
    if multiplayer.is_server():
        _heal_on_server(multiplayer.get_remote_sender_id())

func _heal_on_server(id: int) -> bool:
    if not multiplayer.is_server() or not players.has(id):
        return false
    var hp := int(player_health.get(id, 0))
    if hp <= 0 or hp >= MAX_HEALTH or not _near_campfire(id):
        return false
    var now := Time.get_ticks_msec()
    if now - int(healing_cooldowns.get(id, now - 3000)) < 3000:
        return false
    var old_inventory: Dictionary = player_inventories.get(id, _empty_inventory()).duplicate(true)
    if int(old_inventory.get("herb", 0)) < 2:
        return false
    var inventory := old_inventory.duplicate(true)
    inventory["herb"] = int(inventory["herb"]) - 2
    player_inventories[id] = inventory
    if player_identity_keys.has(id):
        var key: String = player_identity_keys[id]
        persistent_profiles[key]["inventory"] = inventory.duplicate(true)
    if not _save_world_state():
        player_inventories[id] = old_inventory
        if player_identity_keys.has(id):
            persistent_profiles[player_identity_keys[id]]["inventory"] = old_inventory.duplicate(true)
        return false
    healing_cooldowns[id] = now
    player_health[id] = mini(MAX_HEALTH, hp + 35)
    health_snapshot_for.rpc(id, player_health[id])
    if id == own_id:
        health_snapshot(player_health[id], MAX_HEALTH)
        inventory_snapshot(inventory)
    else:
        health_snapshot.rpc_id(id, player_health[id], MAX_HEALTH)
        inventory_snapshot.rpc_id(id, inventory)
    return true

func _combat_server_tick(delta: float) -> void:
    if not multiplayer.is_server() or multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
        return
    var now := Time.get_ticks_msec()
    for id in hero_mana:
        if int(player_choices.get(id,-1)) != HERO_CLASSES.MAGE or not players.has(id):
            continue
        if int(player_health.get(id,0)) <= 0:
            continue
        var before := int(hero_mana[id])
        hero_mana[id] = minf(float(HERO_CLASSES.MAGE_MANA_MAX),
            float(hero_mana[id])+float(HERO_CLASSES.MAGE_MANA_REGEN_PER_SEC)*delta)
        if int(hero_mana[id]) != before:
            _send_mana_snapshot(int(id))
    mage_health_regen_accum += delta
    if mage_health_regen_accum >= 1.0:
        mage_health_regen_accum = 0.0
        for id in player_health:
            if int(player_choices.get(id,-1)) != HERO_CLASSES.MAGE:
                continue
            var hp: int = int(player_health[id])
            if hp <= 0 or hp >= MAX_HEALTH:
                continue
            player_health[id] = mini(MAX_HEALTH,hp+2)
            health_snapshot_for.rpc(int(id),int(player_health[id]))
            if id == own_id:
                health_snapshot(int(player_health[id]),MAX_HEALTH)
            elif multiplayer.get_peers().has(id):
                health_snapshot.rpc_id(int(id),int(player_health[id]),MAX_HEALTH)
    _tick_passive_creatures(delta,now)
    _raid_server_tick(now)
    _tick_raid_pack(delta, now)
    for id in player_respawn_at.keys():
        if now < int(player_respawn_at[id]):
            continue
        player_respawn_at.erase(id)
        if not players.has(id):
            continue
        var world: Node3D = get_node("Eldoria_Forest")
        var at := Vector3(0, world.height_at(0, 0) + 1, 0)
        players[id].position = at
        player_health[id] = MAX_HEALTH
        health_snapshot_for.rpc(int(id), MAX_HEALTH)
        if int(id) == own_id:
            health_snapshot(MAX_HEALTH, MAX_HEALTH)
        else:
            health_snapshot.rpc_id(int(id), MAX_HEALTH, MAX_HEALTH)
            correct_own_position.rpc_id(int(id), at)
    if not wolf_alive:
        if raid.phase == "night" and wolf_respawn_at > 0 and now >= wolf_respawn_at:
            _reset_wolf()
            wolf_snapshot.rpc(wolf_position, wolf_health, true, Vector3.ZERO)
        return
    var target_id := _choose_wolf_target(wolf_position,now)
    wolf_direction = Vector3.ZERO
    if target_id != 0:
        var destination: Vector3 = players[target_id].position
        var displacement := Vector3(destination.x - wolf_position.x, 0, destination.z - wolf_position.z)
        var distance := displacement.length()
        if distance > 1.5:
            wolf_direction = displacement.normalized()
            var chill_factor := 0.45 if now < int(mage_chilled_until.get(0,0)) else 1.0
            var step := minf(2.5 * chill_factor * delta, distance - 1.5)
            var next := wolf_position + wolf_direction * step
            var world: Node3D = get_node("Eldoria_Forest")
            next.y = world.height_at(next.x, next.z) + 0.1
            wolf_position = next
        elif absf(destination.y - wolf_position.y) <= 2.8 and now - wolf_last_hit_at >= 1500:
            wolf_last_hit_at = now
            if _damage_player_on_server(target_id, 12):
                wolf_attack_visual.rpc(0)
                if not is_dedicated:
                    wolf_attack_visual(0)
    wolf_sync_timer += delta
    if wolf_sync_timer >= 0.15:
        wolf_sync_timer = 0.0
        for remote_id in _ready_snapshot_peers():
            wolf_snapshot.rpc_id(remote_id,wolf_position,wolf_health,wolf_alive,wolf_direction)

# WebSocket clients can enter CLOSING before SceneMultiplayer emits
# peer_disconnected. Sending high-frequency snapshots to those sockets
# otherwise triggers repeated engine-level STATE_OPEN errors.
func _ready_snapshot_peers() -> Array[int]:
    var ids: Array[int] = []
    if not multiplayer.is_server():
        return ids
    if multiplayer.multiplayer_peer is WebSocketMultiplayerPeer:
        var sockets := multiplayer.multiplayer_peer as WebSocketMultiplayerPeer
        for id in multiplayer.get_peers():
            var socket := sockets.get_peer(id)
            if socket != null and socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
                ids.append(int(id))
    else:
        for id in multiplayer.get_peers():
            ids.append(int(id))
    return ids

func _tick_raid_pack(delta: float, now: int) -> void:
    if pack_wolves.is_empty():
        return
    var world: Node3D = get_node("Eldoria_Forest")
    for pack_id in pack_wolves:
        var enemy: Dictionary = pack_wolves[pack_id]
        if not enemy["alive"]:
            continue
        var at: Vector3 = enemy["position"]
        var target_id := _choose_wolf_target(at,now)
        enemy["direction"] = Vector3.ZERO
        if target_id != 0:
            var destination: Vector3 = players[target_id].position
            var direct := Vector3(destination.x-at.x, 0, destination.z-at.z)
            var displacement := direct
            # Two pack wolves approach a distant target from opposite sides
            # rather than occupying exactly the same chase trajectory.
            if direct.length() > 3.2:
                var lateral := Vector3(-direct.z,0,direct.x).normalized()
                var side := -1.0 if int(pack_id) % 2 == 0 else 1.0
                displacement += lateral * side * 1.6
            var distance := displacement.length()
            if distance > 1.5:
                enemy["direction"] = displacement.normalized()
                var chill_factor := 0.45 if now < int(mage_chilled_until.get(int(pack_id),0)) else 1.0
                var next: Vector3 = at + enemy["direction"] * minf(2.5*chill_factor*delta, distance-1.5)
                next.y = world.height_at(next.x, next.z) + 0.1
                enemy["position"] = next
            elif absf(destination.y-at.y) <= 2.8 and now-int(enemy["last_hit"]) >= 1500:
                enemy["last_hit"] = now
                if _damage_player_on_server(target_id, 12):
                    wolf_attack_visual.rpc(int(pack_id))
                    if not is_dedicated:
                        wolf_attack_visual(int(pack_id))
        elif camp_target_id != 0:
            var offset := Vector3(raid_anchor.x-at.x, 0, raid_anchor.z-at.z)
            if offset.length() > 1.9:
                enemy["direction"] = offset.normalized()
                var chill_factor := 0.45 if now < int(mage_chilled_until.get(int(pack_id),0)) else 1.0
                var step: Vector3 = at + enemy["direction"] * minf(2.5*chill_factor*delta, offset.length()-1.9)
                step.y = world.height_at(step.x, step.z) + 0.1
                enemy["position"] = step
            else:
                if _damage_camp(9, now, int(pack_id)):
                    wolf_attack_visual.rpc(int(pack_id))
                    if not is_dedicated:
                        wolf_attack_visual(int(pack_id))
    if raid.phase != "night":
        _clear_raid_pack()
        return
    pack_sync_timer += delta
    if pack_sync_timer >= 0.15:
        pack_sync_timer = 0.0
        for remote_id in _ready_snapshot_peers():
            for pack_id in pack_wolves:
                var enemy: Dictionary = pack_wolves[pack_id]
                if enemy["alive"]:
                    pack_wolf_snapshot.rpc_id(remote_id,int(pack_id),enemy["position"],int(enemy["hp"]),true,enemy["direction"])

func _spawn_passive_creatures() -> void:
    if not multiplayer.is_server():
        return
    passive_creatures = PASSIVE_SCRIPT.construct(get_node("Eldoria_Forest"))
    passive_sync_timer = 0.0
    if not is_dedicated:
        for creature_id in passive_creatures:
            var critter: Dictionary = passive_creatures[creature_id]
            passive_snapshot(int(creature_id),critter["species"],critter["position"],int(critter["hp"]),true,Vector3.ZERO)

func _tick_passive_creatures(delta: float, now: int) -> void:
    if passive_creatures.is_empty():
        return
    var respawned: bool = PASSIVE_SCRIPT.tick(passive_creatures,players,player_health,
        get_node("Eldoria_Forest"),delta,now)
    passive_sync_timer += delta
    if not respawned and passive_sync_timer < 0.30:
        return
    passive_sync_timer = 0.0
    var remote_ids := _ready_snapshot_peers()
    for creature_id in passive_creatures:
        var mob: Dictionary = passive_creatures[creature_id]
        for remote_id in remote_ids:
            passive_snapshot.rpc_id(remote_id,int(creature_id),mob["species"],mob["position"],int(mob["hp"]),bool(mob["alive"]),mob["direction"])
        if not is_dedicated:
            passive_snapshot(int(creature_id),mob["species"],mob["position"],int(mob["hp"]),bool(mob["alive"]),mob["direction"])

@rpc("authority", "call_remote", "unreliable")
func passive_snapshot(creature_id: int, species: String, at: Vector3, hp: int, alive: bool, direction: Vector3) -> void:
    if is_dedicated or creature_id < 1 or creature_id > PASSIVE_SCRIPT.SPAWNS.size():
        return
    if species not in ["rabbit","deer","dummy"] or not at.is_finite() or at.length() > 5000:
        return
    if not passive_actors.has(creature_id):
        var actor: Node3D = PASSIVE_ACTOR_SCRIPT.new()
        actor.setup(species)
        actor.name = "Passive_%d_%s" % [creature_id,species]
        add_child(actor)
        passive_actors[creature_id] = actor
    passive_actors[creature_id].update_state(at,clampi(hp,0,55),alive,direction)

func _damage_passive_on_server(player_id: int, creature_id: int, damage: int, now: int) -> bool:
    if not multiplayer.is_server() or not players.has(player_id) or not passive_creatures.has(creature_id):
        return false
    if int(player_health.get(player_id,0)) <= 0 or damage <= 0:
        return false
    var animal: Dictionary = passive_creatures[creature_id]
    if not bool(animal["alive"]):
        return false
    var weapon := str(equipped_combat.get(player_id,"unarmed"))
    if animal["species"] == "dummy":
        var hit_key := "%d:%d" % [player_id,creature_id]
        if now - int(training_last_hit.get(hit_key,now-2000)) < 2000:
            return false
        training_last_hit[hit_key] = now
        if weapon in ["bow","spear"]:
            _award_skill_xp(player_id,"archery" if weapon == "bow" else "spear",3)
        _send_combat_impact(animal["position"] + Vector3.UP*1.05,0,"training")
        return true
    animal["hp"] = maxi(0,int(animal["hp"])-damage)
    _send_combat_impact(animal["position"]+Vector3.UP*(0.8 if animal["species"] == "deer" else 0.45),damage,"wildlife")
    if weapon in ["bow","spear"]:
        _award_skill_xp(player_id,"archery" if weapon == "bow" else "spear",2)
    var points := PASSIVE_SCRIPT.HIT_XP
    if int(animal["hp"]) == 0:
        animal["alive"] = false
        animal["respawn_at"] = now + PASSIVE_SCRIPT.RESPAWN_MS
        animal["direction"] = Vector3.ZERO
        points += PASSIVE_SCRIPT.DEFEAT_XP
    practice_points[player_id] = mini(1000000,int(practice_points.get(player_id,0))+points)
    if player_id == own_id:
        practice_snapshot(int(practice_points[player_id]))
    else:
        practice_snapshot.rpc_id(player_id,int(practice_points[player_id]))
    passive_snapshot.rpc(creature_id,animal["species"],animal["position"],int(animal["hp"]),bool(animal["alive"]),animal["direction"])
    if not is_dedicated:
        passive_snapshot(creature_id,animal["species"],animal["position"],int(animal["hp"]),bool(animal["alive"]),animal["direction"])
    return true

@rpc("authority","call_remote","reliable")
func practice_snapshot(points: int) -> void:
    if live_ui != null:
        live_ui.set_practice_points(clampi(points,0,1000000))

func _damage_player_on_server(id: int, damage: int) -> bool:
    if not multiplayer.is_server() or not players.has(id) or int(player_health.get(id, 0)) <= 0:
        return false
    if (not wolf_alive and pack_wolves.is_empty()) or damage <= 0:
        return false
    if int(player_choices.get(id,-1)) == HERO_CLASSES.KNIGHT:
        damage = maxi(1,ceili(float(damage)*HERO_CLASSES.KNIGHT_DAMAGE_TAKEN))
    if str(equipped_combat.get(id,"")) == "shield" and int(player_inventories.get(id,{}).get("shield",0)) > 0:
        damage = COMBAT_PROGRESSION.shield_damage_taken(damage,
            int(player_skills.get(id,{}).get("defense",0)))
        _award_skill_xp(id,"defense",1)
        shield_block_visual.rpc(id)
        if not is_dedicated:
            shield_block_visual(id)
    player_health[id] = maxi(0, int(player_health[id]) - damage)
    var remaining := int(player_health[id])
    health_snapshot_for.rpc(id, remaining)
    if id == own_id:
        health_snapshot(remaining, MAX_HEALTH)
    elif multiplayer.get_peers().has(id):
        health_snapshot.rpc_id(id, remaining, MAX_HEALTH)
    if remaining == 0:
        player_respawn_at[id] = Time.get_ticks_msec() + 4000
    player_hurt_visual.rpc(id)
    if not is_dedicated:
        player_hurt_visual(id)
    return true

@rpc("authority","call_remote","unreliable")
func shield_block_visual(id: int) -> void:
    if players.has(id):
        players[id].shield_block()

@rpc("authority","call_remote","unreliable")
func player_hurt_visual(id: int) -> void:
    if not is_dedicated and players.has(id):
        players[id].hit_reaction()

func _try_attack() -> void:
    if own_id == 0 or not players.has(own_id) or int(player_health.get(own_id, MAX_HEALTH)) <= 0:
        return
    if int(player_choices.get(own_id,-1)) == HERO_CLASSES.KNIGHT and (
        (str(equipped_combat.get(own_id,"unarmed")) == "shield") if multiplayer.is_server() else
        (live_ui != null and live_ui.combat_equipment == "shield")):
        if multiplayer.is_server():
            _shield_taunt_on_server(own_id)
        else:
            request_shield_taunt.rpc_id(1)
        return
    var aim := _bow_aim_direction()
    if int(player_choices.get(own_id,-1)) == HERO_CLASSES.MAGE and (
            (str(equipped_combat.get(own_id,"unarmed")) == "unarmed") if multiplayer.is_server() else
            (live_ui != null and live_ui.combat_equipment == "unarmed")):
        if multiplayer.is_server():
            _mage_attack_on_server(own_id,aim,mage_spell_index)
        else:
            request_mage_attack.rpc_id(1,aim,mage_spell_index)
        return
    if multiplayer.is_server():
        _attack_on_server(own_id, aim)
    else:
        request_attack.rpc_id(1, aim)

func _bow_aim_direction() -> Vector3:
    # Camera yaw and pitch are input-only; origin and hit detection are
    # reconstructed from authoritative player/world positions on the server.
    return Vector3(0.0, sin(input_driver.pitch), -cos(input_driver.pitch)).rotated(Vector3.UP, input_driver.yaw).normalized()

@rpc("any_peer", "reliable")
func request_attack(aim: Vector3) -> void:
    if multiplayer.is_server():
        _attack_on_server(multiplayer.get_remote_sender_id(), aim)

func _attack_on_server(id: int, aim: Vector3 = Vector3.ZERO) -> bool:
    if not multiplayer.is_server() or not players.has(id) or int(player_health.get(id, 0)) <= 0:
        return false
    if str(equipped_combat.get(id,"unarmed")) == "bow":
        return _bow_attack_on_server(id, aim)
    if not wolf_alive and pack_wolves.is_empty() and passive_creatures.is_empty():
        _attack_feedback(id,"Нет целей поблизости")
        return false
    var now := Time.get_ticks_msec()
    if now - int(last_attack_at.get(id, now - 1000)) < 650:
        return false
    var actor: Vector3 = players[id].position
    var weapon: String = str(equipped_combat.get(id,"unarmed"))
    var range_sq := 20.25 if weapon == "spear" else 9.0
    # The client aims with camera heading; the server selects only targets
    # IN FRONT of the swing. No more instant hits on wolves behind the player.
    # Only spear requires precise facing. Preserve the established close-range
    # unarmed behavior for early game and existing network co-op combat.
    var facing := Vector2(aim.x,aim.z).normalized() if weapon == "spear" and aim.is_finite() and aim.length_squared() > 0.1 else Vector2.ZERO
    var hit_damage := COMBAT_PROGRESSION.weapon_damage("spear",
        int(player_skills.get(id,{}).get("spear",0))) if weapon == "spear" else 20
    var chosen := 0
    var nearest := range_sq
    if wolf_alive and absf(actor.y-wolf_position.y) <= 3.0:
        var distance_sq := Vector2(actor.x-wolf_position.x, actor.z-wolf_position.z).length_squared()
        if distance_sq <= nearest and _in_attack_arc(actor,wolf_position,facing):
            nearest = distance_sq
            chosen = -1
    for pack_id in pack_wolves:
        var enemy: Dictionary = pack_wolves[pack_id]
        if not enemy["alive"]:
            continue
        var at: Vector3 = enemy["position"]
        var distance_sq := Vector2(actor.x-at.x, actor.z-at.z).length_squared()
        if absf(actor.y-at.y) <= 3.0 and distance_sq < nearest and _in_attack_arc(actor,at,facing):
            nearest = distance_sq
            chosen = int(pack_id)
    for creature_id in passive_creatures:
        var animal: Dictionary = passive_creatures[creature_id]
        if not bool(animal["alive"]):
            continue
        var at: Vector3 = animal["position"]
        var distance_sq := Vector2(actor.x-at.x,actor.z-at.z).length_squared()
        if absf(actor.y-at.y) <= 3.0 and distance_sq < nearest and _in_attack_arc(actor,at,facing):
            nearest = distance_sq
            chosen = 100+int(creature_id)
    if chosen == 0:
        combat_swing.rpc(id)
        if id == own_id:
            _play_attack(id)
        _attack_feedback(id,"Мимо! Цель должна быть перед вами (до %s м)" %
            ("4,5" if weapon == "spear" else "3"))
        return false
    last_attack_at[id] = now
    if chosen > 100:
        combat_swing.rpc(id)
        if id == own_id:
            _play_attack(id)
        var landed := _damage_passive_on_server(id,chosen-100,hit_damage,now)
        if landed:
            _attack_feedback(id,"Попадание копьём!" if weapon == "spear" else "Попадание!")
        return landed
    if chosen > 0:
        var enemy: Dictionary = pack_wolves[chosen]
        enemy["hp"] = maxi(0, int(enemy["hp"])-hit_damage)
        _send_combat_impact(enemy["position"]+Vector3.UP*0.8,hit_damage,"wolf")
        if weapon == "spear":
            _award_skill_xp(id,"spear",2)
        combat_swing.rpc(id)
        if id == own_id:
            _play_attack(id)
        if enemy["hp"] == 0:
            enemy["alive"] = false
            var outcome: String = raid.wolf_defeated(now)
            if outcome == "night_won":
                _reward_raid_survivors()
                _clear_raid_pack()
            if outcome != "":
                _broadcast_raid_state(now)
        pack_wolf_snapshot.rpc(chosen, enemy["position"], int(enemy["hp"]), bool(enemy["alive"]), enemy["direction"])
        _attack_feedback(id,"Копьё: попадание! -%d HP" % hit_damage if weapon == "spear"
            else "Попадание! -%d HP" % hit_damage)
        return true
    wolf_health = maxi(0, wolf_health - hit_damage)
    _send_combat_impact(wolf_position+Vector3.UP*0.8,hit_damage,"wolf")
    if weapon == "spear":
        _award_skill_xp(id,"spear",2)
    combat_swing.rpc(id)
    if id == own_id:
        _play_attack(id)
    if wolf_health == 0:
        wolf_alive = false
        wolf_respawn_at = now + 10000
        var result: String = raid.wolf_defeated(now)
        if result == "wolf_defeated":
            wolf_respawn_at = now + 2700
            _broadcast_raid_state(now)
        elif result == "night_won":
            _clear_raid_pack()
            _reward_raid_survivors()
            _broadcast_raid_state(now)
    wolf_snapshot.rpc(wolf_position, wolf_health, wolf_alive, wolf_direction)
    _attack_feedback(id,"Копьё: попадание! -%d HP" % hit_damage if weapon == "spear"
        else "Попадание! -%d HP" % hit_damage)
    return true

func _in_attack_arc(from: Vector3, target: Vector3, facing: Vector2) -> bool:
    if facing.length_squared() < 0.5: # Legacy server tests invoke melee without aim.
        return true
    var to_target := Vector2(target.x-from.x,target.z-from.z)
    return to_target.length_squared() < 0.04 or to_target.normalized().dot(facing) >= 0.35

func _spear_reticle_state(origin: Vector3, direction: Vector3) -> String:
    var front := Vector2(direction.x,direction.z).normalized()
    var candidates: Array[Vector3] = []
    if wolf_alive:
        candidates.append(wolf_position)
    for wolf in pack_wolves.values():
        if bool(wolf["alive"]):
            candidates.append(wolf["position"])
    for animal in passive_creatures.values():
        if bool(animal["alive"]):
            candidates.append(animal["position"])
    for target in candidates:
        if absf(origin.y-target.y) <= 3.0 and Vector2(origin.x-target.x,
                origin.z-target.z).length_squared() <= 4.5*4.5 and _in_attack_arc(
                    origin,target,front):
            return "target"
    return "none"

func _bow_reticle_state(origin: Vector3, direction: Vector3) -> String:
    if int(player_inventories.get(own_id,{}).get("arrow",0)) <= 0:
        return "no_ammo"
    var world: Node3D = get_node("Eldoria_Forest")
    var blocked_at: float = world.arrow_block_fraction(origin,origin+direction*12.0)*12.0
    var target_at := INF
    if wolf_alive:
        target_at = minf(target_at,_ray_wolf_hit_distance(
            origin,direction,wolf_position+Vector3.UP*0.65))
    for wolf in pack_wolves.values():
        if bool(wolf["alive"]):
            target_at = minf(target_at,_ray_wolf_hit_distance(
                origin,direction,wolf["position"]+Vector3.UP*0.65))
    for animal in passive_creatures.values():
        if not bool(animal["alive"]):
            continue
        var height: float = 0.8 if animal["species"] == "deer" else 0.35
        var radius: float = 0.75 if animal["species"] == "deer" else 0.40
        target_at = minf(target_at,_ray_wolf_hit_distance(
            origin,direction,animal["position"]+Vector3.UP*height,radius))
    if target_at < blocked_at:
        return "target"
    return "blocked" if blocked_at < 11.99 else "none"

func _attack_feedback(id: int, message: String) -> void:
    if id == own_id:
        attack_feedback(message)
    elif multiplayer.get_peers().has(id):
        attack_feedback.rpc_id(id,message)

func _send_combat_impact(at: Vector3, damage: int, kind: String) -> void:
    if not multiplayer.is_server() or not at.is_finite():
        return
    combat_impact.rpc(at,damage,kind)
    if not is_dedicated:
        combat_impact(at,damage,kind)

@rpc("authority","call_remote","reliable")
func combat_impact(at: Vector3, damage: int, kind: String) -> void:
    if is_dedicated or not at.is_finite() or at.length() > 5000:
        return
    if harvest_visuals != null:
        harvest_visuals.play_combat_impact(kind,at,damage)
        if kind in ["wolf","wildlife"] and damage > 0:
            harvest_visuals.play_sound("wolf_hit",at)
        elif kind == "obstacle":
            harvest_visuals.play_sound("obstacle_hit",at)

@rpc("authority","call_remote","reliable")
func attack_feedback(message: String) -> void:
    if live_ui != null:
        live_ui.show_combat_feedback(message)

# Aim direction comes from the player, but all geometry, targets, ammunition,
# cooldown and damage are resolved on the authoritative server.
@rpc("any_peer", "reliable")
func request_mage_attack(aim: Vector3, spell: int) -> void:
    if multiplayer.is_server():
        _mage_attack_on_server(multiplayer.get_remote_sender_id(),aim,spell)

func _mage_attack_on_server(id: int, aim: Vector3, spell: int) -> bool:
    if not multiplayer.is_server() or int(player_choices.get(id,-1)) != HERO_CLASSES.MAGE:
        return false
    if spell < 0 or spell >= MAGE_SPELLS.size():
        return false
    if str(equipped_combat.get(id,"unarmed")) != "unarmed":
        return false
    return _bow_attack_on_server(id,aim,spell)

func _bow_attack_on_server(id: int, aim: Vector3, spell: int = -1) -> bool:
    if not multiplayer.is_server() or not players.has(id) or int(player_health.get(id,0)) <= 0:
        return false
    if spell < 0 and (str(equipped_combat.get(id,"unarmed")) != "bow" or int(player_inventories.get(id,{}).get("bow",0)) < 1):
        return false
    if not aim.is_finite() or absf(aim.length()-1.0) > 0.05 or aim.y < -0.96 or aim.y > 0.80:
        return false
    var hit_damage := COMBAT_PROGRESSION.weapon_damage("bow",
        int(player_skills.get(id,{}).get("archery",0)))
    if spell >= 0:
        hit_damage = MAGE_SPELL_DAMAGE[spell]
    var now := Time.get_ticks_msec()
    if now - int(last_attack_at.get(id,now-1000)) < 650:
        return false
    var inv: Dictionary = player_inventories.get(id,{}).duplicate(true)
    if spell >= 0:
        if float(hero_mana.get(id,0.0)) < MAGE_SPELL_COST[spell]:
            _attack_feedback(id,"Недостаточно маны")
            return false
        hero_mana[id] = float(hero_mana[id])-MAGE_SPELL_COST[spell]
        _send_mana_snapshot(id)
    else:
        if int(inv.get("arrow",0)) < 1:
            _attack_feedback(id,"Нет стрел! Создайте их в мастерской")
            return false
        var before := inv.duplicate(true)
        inv["arrow"] = int(inv["arrow"])-1
        player_inventories[id] = inv
        if player_identity_keys.has(id):
            persistent_profiles[player_identity_keys[id]]["inventory"] = inv.duplicate(true)
        if not _save_world_state():
            player_inventories[id] = before
            if player_identity_keys.has(id):
                persistent_profiles[player_identity_keys[id]]["inventory"] = before.duplicate(true)
            return false
    last_attack_at[id] = now
    if spell < 0:
        if id == own_id:
            inventory_snapshot(inv)
        else:
            inventory_snapshot.rpc_id(id,inv)
    var origin: Vector3 = players[id].position + Vector3.UP*0.8
    var end: Vector3 = origin + aim*12.0
    var world: Node3D = get_node("Eldoria_Forest")
    var nearest: float = world.arrow_block_fraction(origin,end) * 12.0
    var struck := 0
    if wolf_alive:
        var distance := _ray_wolf_hit_distance(origin,aim,wolf_position+Vector3.UP*0.65)
        if distance < nearest:
            nearest = distance
            struck = -1
    for pack_id in pack_wolves:
        var wolf: Dictionary = pack_wolves[pack_id]
        if not bool(wolf["alive"]):
            continue
        var distance := _ray_wolf_hit_distance(origin,aim,wolf["position"]+Vector3.UP*0.65)
        if distance < nearest:
            nearest = distance
            struck = int(pack_id)
    for creature_id in passive_creatures:
        var animal: Dictionary = passive_creatures[creature_id]
        if not bool(animal["alive"]):
            continue
        var hit_center: Vector3 = animal["position"]+Vector3.UP*(0.8 if animal["species"] == "deer" else 0.35)
        var distance := _ray_wolf_hit_distance(origin,aim,hit_center,
            0.75 if animal["species"] == "deer" else 0.40)
        if distance < nearest:
            nearest = distance
            struck = 100+int(creature_id)
    var impact := origin + aim*nearest
    if spell >= 0:
        mage_spell_visual.rpc(id,origin,impact,spell)
        if not is_dedicated:
            mage_spell_visual(id,origin,impact,spell)
    else:
        bow_shot_visual.rpc(origin, impact)
        if not is_dedicated:
            bow_shot_visual(origin, impact)
        combat_swing.rpc(id)
        if id == own_id:
            _play_attack(id)
    if struck == 0:
        if nearest < 11.99:
            _send_combat_impact(impact,0,"obstacle")
        _attack_feedback(id,("Заклинание попало в препятствие" if nearest < 11.99 else "Магия: промах") if spell >= 0 else ("Стрела попала в препятствие" if nearest < 11.99 else "Промах — наведите прицел на цель"))
        return true # A real shot can miss; ammunition was still consumed.
    if struck > 100:
        var landed := _damage_passive_on_server(id,struck-100,hit_damage,now)
        if landed:
            _attack_feedback(id,"Точно! -%d HP" % hit_damage)
        return landed
    if struck > 0:
        var wolf: Dictionary = pack_wolves[struck]
        wolf["hp"] = maxi(0,int(wolf["hp"])-hit_damage)
        _send_combat_impact(wolf["position"]+Vector3.UP*0.8,hit_damage,"wolf")
        if spell < 0:
            _award_skill_xp(id,"archery",2)
        if wolf["hp"] == 0:
            wolf["alive"] = false
            var outcome: String = raid.wolf_defeated(now)
            if outcome == "night_won":
                _reward_raid_survivors()
                _clear_raid_pack()
            if outcome != "":
                _broadcast_raid_state(now)
        pack_wolf_snapshot.rpc(struck,wolf["position"],int(wolf["hp"]),bool(wolf["alive"]),wolf["direction"])
        if spell >= 0:
            _mage_spell_secondary(spell,struck,wolf["position"],now)
    else:
        wolf_health = maxi(0,wolf_health-hit_damage)
        _send_combat_impact(wolf_position+Vector3.UP*0.8,hit_damage,"wolf")
        if spell < 0:
            _award_skill_xp(id,"archery",2)
        if wolf_health == 0:
            wolf_alive = false
            wolf_respawn_at = now+10000
            var outcome: String = raid.wolf_defeated(now)
            if outcome == "wolf_defeated":
                wolf_respawn_at = now+2700
                _broadcast_raid_state(now)
            elif outcome == "night_won":
                _clear_raid_pack()
                _reward_raid_survivors()
                _broadcast_raid_state(now)
        wolf_snapshot.rpc(wolf_position,wolf_health,wolf_alive,wolf_direction)
        if spell >= 0:
            _mage_spell_secondary(spell,0,wolf_position,now)
    _attack_feedback(id,("Магия: -%d HP" if spell >= 0 else "Попадание из лука! -%d HP") % hit_damage)
    return true

func _mage_spell_secondary(spell: int, primary_id: int, point: Vector3, now: int) -> void:
    # Ice slows the target for three seconds. Fire splashes nearby wolves;
    # lightning jumps to the closest additional wolf. Secondary damage cannot
    # kill outright: this keeps raid kill accounting on the direct-hit path.
    if spell == 1:
        mage_chilled_until[primary_id] = now + 3000
        return
    if spell != 0 and spell != 2:
        return
    var targets: Array[int] = []
    for key in pack_wolves:
        var enemy: Dictionary = pack_wolves[key]
        if int(key) != primary_id and bool(enemy["alive"]) and point.distance_to(enemy["position"]) <= (2.8 if spell == 0 else 5.0):
            targets.append(int(key))
    if primary_id != 0 and wolf_alive and point.distance_to(wolf_position) <= (2.8 if spell == 0 else 5.0):
        targets.append(0)
    targets.sort()
    if spell == 2 and targets.size() > 1:
        targets.resize(1)
    var extra_damage := 8 if spell == 0 else 14
    for key in targets:
        if key == 0:
            wolf_health = maxi(1,wolf_health-extra_damage)
            wolf_snapshot.rpc(wolf_position,wolf_health,wolf_alive,wolf_direction)
            _send_combat_impact(wolf_position+Vector3.UP*0.8,extra_damage,"wolf")
        else:
            var enemy: Dictionary = pack_wolves[key]
            enemy["hp"] = maxi(1,int(enemy["hp"])-extra_damage)
            pack_wolf_snapshot.rpc(key,enemy["position"],int(enemy["hp"]),true,enemy["direction"])
            _send_combat_impact(enemy["position"]+Vector3.UP*0.8,extra_damage,"wolf")

func _ray_wolf_hit_distance(origin: Vector3, direction: Vector3, center: Vector3, radius: float = 0.8) -> float:
    var to_center := center-origin
    var along := to_center.dot(direction)
    if along < 0.0 or along > 12.85:
        return INF
    var sideways_sq := to_center.length_squared()-along*along
    if sideways_sq >= radius*radius:
        return INF
    var entry := maxf(0.0,along-sqrt(radius*radius-sideways_sq))
    return entry if entry <= 12.0 else INF

@rpc("authority", "call_remote", "reliable")
func combat_swing(id: int) -> void:
    _play_attack(id)

@rpc("authority", "call_remote", "unreliable")
func bow_shot_visual(start: Vector3, target: Vector3) -> void:
    if is_dedicated or not start.is_finite() or not target.is_finite() or start.distance_to(target) > 13.0:
        return
    var direction := target-start
    if direction.length() < 0.01:
        return
    if harvest_visuals != null:
        harvest_visuals.play_sound("bow",start)
    var tracer := MeshInstance3D.new()
    tracer.name = "ArrowTracer"
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.024
    mesh.bottom_radius = 0.024
    mesh.height = 0.55
    tracer.mesh = mesh
    tracer.position = start
    tracer.quaternion = Quaternion(Vector3.UP, direction.normalized())
    add_child(tracer)
    var tween := create_tween()
    tween.tween_property(tracer, "position", target, 0.16)
    tween.tween_callback(tracer.queue_free)

@rpc("authority","call_remote","reliable")
func mage_spell_visual(caster_id: int, start: Vector3, target: Vector3, spell: int) -> void:
    if is_dedicated or spell < 0 or spell >= MAGE_SPELLS.size() or not start.is_finite() or not target.is_finite() or start.distance_to(target) > 13.0:
        return
    var palette := [Color("ff923e"),Color("8be5ff"),Color("c4a3ff")]
    var hue: Color = palette[spell]
    if players.has(caster_id):
        players[caster_id].hero_ability_animation("spell")
    var orb := MeshInstance3D.new()
    orb.name = "MagicProjectile"
    var mesh := SphereMesh.new()
    mesh.radius = [0.18,0.13,0.23][spell]
    mesh.height = mesh.radius*2.0
    orb.mesh = mesh
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = hue
    material.emission_enabled = true
    material.emission = hue
    material.emission_energy_multiplier = 3.0
    orb.material_override = material
    orb.position = start
    add_child(orb)
    var tween := create_tween()
    tween.tween_property(orb,"position",target,[0.27,0.21,0.11][spell])
    tween.tween_callback(func() -> void:
        if not is_instance_valid(orb):
            return
        var impact := MeshInstance3D.new()
        impact.mesh = SphereMesh.new()
        impact.position = target
        impact.scale = Vector3.ONE*0.08
        impact.material_override = material
        add_child(impact)
        orb.queue_free()
        var burst := create_tween()
        burst.set_parallel(true)
        burst.tween_property(impact,"scale",Vector3.ONE*[0.8,0.65,1.1][spell],0.22)
        burst.tween_property(impact,"transparency",1.0,0.22)
        burst.chain().tween_callback(impact.queue_free))

func _play_attack(id: int) -> void:
    if players.has(id):
        players[id].melee_attack()
        if harvest_visuals != null and not is_dedicated:
            var equipment: String = str(players[id].combat_item)
            if equipment == "spear":
                harvest_visuals.play_sound("spear_swing",players[id].position)
            elif equipment == "shield":
                harvest_visuals.play_sound("shield_hit",players[id].position)
            elif equipment == "unarmed":
                harvest_visuals.play_sound("punch",players[id].position)

@rpc("authority", "call_remote", "reliable")
func health_snapshot(hp: int, maximum: int) -> void:
    if own_id != 0:
        player_health[own_id] = clampi(hp, 0, MAX_HEALTH)
    if live_ui != null:
        live_ui.set_health(hp, maximum)

@rpc("authority", "call_remote", "reliable")
func health_snapshot_for(id: int, hp: int) -> void:
    player_health[id] = clampi(hp, 0, MAX_HEALTH)

@rpc("authority", "call_remote", "reliable")
func wolf_snapshot(at: Vector3, hp: int, alive: bool, direction: Vector3) -> void:
    if not at.is_finite() or at.length() > 5000:
        return
    wolf_position = at
    wolf_health = clampi(hp, 0, WOLF_MAX_HEALTH)
    wolf_alive = alive
    wolf_direction = direction
    if wolf_actor != null:
        if not alive and wolf_actor.initialized and not wolf_actor.down and harvest_visuals != null:
            harvest_visuals.play_sound("wolf_death",at)
        wolf_actor.update_state(at, wolf_health, wolf_alive, direction)

@rpc("authority","call_remote","unreliable")
func wolf_attack_visual(wolf_id: int) -> void:
    if is_dedicated or wolf_id < 0 or wolf_id > 2:
        return
    var actor: Node3D = wolf_actor if wolf_id == 0 else pack_actors.get(wolf_id)
    if actor != null and is_instance_valid(actor):
        actor.play_bite()
        if harvest_visuals != null:
            harvest_visuals.play_sound("wolf_bite",actor.position)

func _combat_ui_action(kind: String) -> void:
    if kind == "attack":
        _try_attack()
    elif kind == "ability":
        _try_hero_ability()
    elif kind == "spell":
        _cycle_mage_spell()

func _cycle_mage_spell() -> void:
    if own_id <= 0 or int(player_choices.get(own_id,-1)) != HERO_CLASSES.MAGE:
        return
    mage_spell_index = (mage_spell_index+1) % MAGE_SPELLS.size()
    if live_ui != null:
        live_ui.hud.set_spell(mage_spell_index)
        live_ui.show_message(["Огненный шар · 14 маны", "Ледяная стрела · 22 маны", "Молния · 34 маны"][mage_spell_index])

func _try_hero_ability() -> void:
    if own_id <= 0 or not players.has(own_id) or int(player_health.get(own_id,0)) <= 0:
        return
    var axis: Vector2 = input_driver.get_move_vector()
    var direction := Vector3(axis.x,0,axis.y).rotated(Vector3.UP,input_driver.yaw)
    if direction.length_squared() < 0.01:
        direction = Vector3.FORWARD.rotated(Vector3.UP,input_driver.yaw)
    direction = direction.normalized()
    if multiplayer.is_server():
        _hero_ability_on_server(own_id,direction)
    else:
        request_hero_ability.rpc_id(1,direction)

@rpc("any_peer","reliable")
func request_hero_ability(direction: Vector3) -> void:
    if multiplayer.is_server():
        _hero_ability_on_server(multiplayer.get_remote_sender_id(),direction)

func _hero_ability_on_server(id: int, direction: Vector3, now: int = -1) -> bool:
    if not multiplayer.is_server() or not players.has(id) or int(player_health.get(id,0)) <= 0:
        return false
    if now < 0:
        now = Time.get_ticks_msec()
    var hero := int(player_choices.get(id,-1))
    if hero == HERO_CLASSES.KNIGHT:
        return _shield_taunt_on_server(id,now)
    if now < int(hero_ability_ready_at.get(id,0)):
        _send_hero_message(id,"Способность: перезарядка")
        return false
    if hero == HERO_CLASSES.ROGUE:
        if not direction.is_finite() or absf(direction.length()-1.0) > 0.05 or absf(direction.y) > 0.05:
            return false
        var world: Node3D = get_node("Eldoria_Forest")
        var before: Vector3 = players[id].position
        var after: Vector3 = world.move_actor(before,direction*HERO_CLASSES.ROGUE_DASH_DISTANCE)
        if after.distance_to(before) < 0.30:
            _send_hero_message(id,"Рывок заблокирован")
            return false
        players[id].position = after
        hero_ability_ready_at[id] = now+HERO_CLASSES.ROGUE_DASH_COOLDOWN_MS
        if id == own_id:
            correct_own_position(after)
        elif multiplayer.get_peers().has(id):
            correct_own_position.rpc_id(id,after)
        sync_position.rpc(id,after)
        hero_ability_visual.rpc(id,"dash")
        if not is_dedicated:
            hero_ability_visual(id,"dash")
        _send_hero_message(id,"Рывок!")
        return true
    if hero == HERO_CLASSES.MAGE:
        if float(hero_mana.get(id,0.0)) < HERO_CLASSES.MAGE_MANA_COST:
            _send_hero_message(id,"Недостаточно маны")
            return false
        var caster: Vector3 = players[id].position
        var target_id := 0
        var missing := 0
        var nearest_sq := INF
        for ally_id in player_health:
            if not players.has(ally_id):
                continue
            var health := int(player_health[ally_id])
            if health <= 0 or health >= MAX_HEALTH:
                continue
            var pos: Vector3 = players[ally_id].position
            var distance_sq := Vector2(caster.x-pos.x,caster.z-pos.z).length_squared()
            if distance_sq > HERO_CLASSES.MAGE_HEAL_RADIUS*HERO_CLASSES.MAGE_HEAL_RADIUS:
                continue
            var deficit := MAX_HEALTH-health
            if deficit > missing or (deficit == missing and distance_sq < nearest_sq):
                target_id = int(ally_id)
                missing = deficit
                nearest_sq = distance_sq
        if target_id == 0:
            _send_hero_message(id,"Рядом нет раненых союзников")
            return false
        hero_mana[id] = float(hero_mana[id])-HERO_CLASSES.MAGE_MANA_COST
        hero_ability_ready_at[id] = now+HERO_CLASSES.MAGE_HEAL_COOLDOWN_MS
        player_health[target_id] = mini(MAX_HEALTH,int(player_health[target_id])+HERO_CLASSES.MAGE_HEAL_HP)
        health_snapshot_for.rpc(target_id,int(player_health[target_id]))
        if target_id == own_id:
            health_snapshot(int(player_health[target_id]),MAX_HEALTH)
        elif multiplayer.get_peers().has(target_id):
            health_snapshot.rpc_id(target_id,int(player_health[target_id]),MAX_HEALTH)
        _send_mana_snapshot(id)
        hero_ability_visual.rpc(id,"heal",target_id)
        if not is_dedicated:
            hero_ability_visual(id,"heal",target_id)
        _send_hero_message(id,"Лечение: +%d HP" % mini(missing,HERO_CLASSES.MAGE_HEAL_HP))
        return true
    return false

@rpc("authority","call_remote","reliable")
func hero_ability_visual(id: int, kind: String, target_id: int = 0) -> void:
    if not is_dedicated and kind in ["dash","heal"] and players.has(id):
        players[id].hero_ability_animation(kind)
        if harvest_visuals != null:
            var position: Vector3 = players[id].position
            if kind == "heal" and players.has(target_id):
                position = players[target_id].position
            harvest_visuals.play_ability_effect(kind,position)
            harvest_visuals.play_sound(kind,position)

func _send_mana_snapshot(id: int) -> void:
    if id == own_id:
        mana_snapshot(int(hero_mana.get(id,0.0)))
    elif multiplayer.get_peers().has(id):
        mana_snapshot.rpc_id(id,int(hero_mana.get(id,0.0)))

@rpc("authority","call_remote","unreliable")
func mana_snapshot(value: int) -> void:
    if live_ui != null:
        live_ui.set_hero_mana(clampi(value,0,HERO_CLASSES.MAGE_MANA_MAX))

func _choose_wolf_target(at: Vector3, now: int) -> int:
    # Active shield defenders take priority only within their limited taunt
    # radius. All positions and equipment are checked from server state.
    var chosen := 0
    var nearest := 14.0 * 14.0
    for player_id in player_health:
        if not players.has(player_id) or int(player_health[player_id]) <= 0:
            continue
        var position: Vector3 = players[player_id].position
        var dist_sq := Vector2(position.x-at.x,position.z-at.z).length_squared()
        if dist_sq < nearest:
            chosen = int(player_id)
            nearest = dist_sq
    var taunter := 0
    var closest_taunt_sq := SHIELD_TAUNT_RANGE * SHIELD_TAUNT_RANGE
    for player_id in shield_taunt_until:
        if not players.has(player_id) or int(player_health.get(player_id,0)) <= 0:
            continue
        if int(shield_taunt_until[player_id]) <= now or str(equipped_combat.get(player_id,"")) != "shield":
            continue
        if int(player_inventories.get(player_id,{}).get("shield",0)) < 1:
            continue
        var position: Vector3 = players[player_id].position
        var dist_sq := Vector2(position.x-at.x,position.z-at.z).length_squared()
        if dist_sq <= closest_taunt_sq:
            taunter = int(player_id)
            closest_taunt_sq = dist_sq
    return taunter if taunter != 0 else chosen

func _shield_taunt_on_server(id: int, now: int = -1) -> bool:
    if not multiplayer.is_server() or not players.has(id) or int(player_health.get(id,0)) <= 0:
        return false
    if int(player_choices.get(id,-1)) != HERO_CLASSES.KNIGHT:
        return false
    if str(equipped_combat.get(id,"")) != "shield" or int(player_inventories.get(id,{}).get("shield",0)) < 1:
        return false
    if now < 0:
        now = Time.get_ticks_msec()
    if now < int(shield_taunt_ready_at.get(id,0)):
        _shield_taunt_feedback(id,"Щит: перезарядка %d с" % ceili(float(shield_taunt_ready_at[id]-now)/1000.0))
        return false
    var at: Vector3 = players[id].position
    var in_range := wolf_alive and Vector2(wolf_position.x-at.x,wolf_position.z-at.z).length_squared() <= SHIELD_TAUNT_RANGE*SHIELD_TAUNT_RANGE
    for pack_id in pack_wolves:
        var wolf: Dictionary = pack_wolves[pack_id]
        if bool(wolf["alive"]) and Vector2(wolf["position"].x-at.x,wolf["position"].z-at.z).length_squared() <= SHIELD_TAUNT_RANGE*SHIELD_TAUNT_RANGE:
            in_range = true
            break
    if not in_range:
        _shield_taunt_feedback(id,"Щит: волков рядом нет")
        return false
    shield_taunt_until[id] = now+SHIELD_TAUNT_DURATION_MS
    shield_taunt_ready_at[id] = now+SHIELD_TAUNT_COOLDOWN_MS
    shield_block_visual.rpc(id)
    shield_taunt_visual.rpc(id, SHIELD_TAUNT_DURATION_MS)
    if not is_dedicated:
        shield_block_visual(id)
        shield_taunt_visual(id, SHIELD_TAUNT_DURATION_MS)
    _shield_taunt_feedback(id,"Волки отвлечены на 5 с · откат 15 с")
    return true

@rpc("any_peer","reliable")
func request_shield_taunt() -> void:
    if multiplayer.is_server():
        _shield_taunt_on_server(multiplayer.get_remote_sender_id())

func _shield_taunt_feedback(id: int, message: String) -> void:
    if id == own_id:
        shield_taunt_message(message)
    else:
        shield_taunt_message.rpc_id(id,message)

@rpc("authority","call_remote","reliable")
func shield_taunt_message(message: String) -> void:
    if live_ui != null:
        live_ui.show_message(message)

@rpc("authority","call_remote","reliable")
func shield_taunt_visual(id: int, duration_ms: int) -> void:
    if is_dedicated or not players.has(id) or duration_ms <= 0 or duration_ms > SHIELD_TAUNT_DURATION_MS:
        return
    var actor: Node3D = players[id]
    # Joining mid-taunt receives the ongoing marker, not a fake new cast burst.
    if duration_ms >= SHIELD_TAUNT_DURATION_MS-150 and harvest_visuals != null:
        harvest_visuals.play_ability_effect("taunt",actor.position)
        harvest_visuals.play_sound("taunt",actor.position)
    var marker: Label3D = actor.get_node_or_null("TauntIndicator")
    if marker == null:
        marker = Label3D.new()
        marker.name = "TauntIndicator"
        marker.text = "ЗАЩИТНИК"
        marker.position = Vector3(0,2.35,0)
        marker.font_size = 30
        marker.modulate = Color("b8edc2")
        marker.outline_modulate = Color("18382a")
        marker.outline_size = 6
        marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        actor.add_child(marker)
    marker.set_meta("until",Time.get_ticks_msec()+duration_ms)
    get_tree().create_timer(float(duration_ms)/1000.0).timeout.connect(func() -> void:
        if is_instance_valid(marker) and Time.get_ticks_msec() >= int(marker.get_meta("until",0)):
            marker.queue_free())


# The server owns resource quantities and player inventories.
# This is an in-memory prototype; a permanent world will require persistence.
func _empty_inventory() -> Dictionary:
    return {"wood":0, "stone":0, "herb":0, "axe":0, "bandage":0, "repair_kit":0, "spear":0, "bow":0, "shield":0, "arrow":0}

func _empty_skills() -> Dictionary:
    return {"archery":0,"spear":0,"defense":0}

func _award_skill_xp(player_id: int, skill: String, points: int) -> bool:
    if not multiplayer.is_server() or not players.has(player_id) or skill not in SKILL_KINDS or points <= 0:
        return false
    var before: Dictionary = player_skills.get(player_id,_empty_skills()).duplicate(true)
    var updated := before.duplicate(true)
    updated[skill] = mini(SKILL_XP_MAX,int(before.get(skill,0))+points)
    if int(updated[skill]) == int(before.get(skill,0)):
        return false
    player_skills[player_id] = updated
    if player_identity_keys.has(player_id):
        persistent_profiles[player_identity_keys[player_id]]["skills"] = updated.duplicate(true)
    if not _save_world_state():
        player_skills[player_id] = before
        if player_identity_keys.has(player_id):
            persistent_profiles[player_identity_keys[player_id]]["skills"] = before.duplicate(true)
        return false
    if player_id == own_id:
        skill_snapshot(updated)
    else:
        skill_snapshot.rpc_id(player_id,updated)
    return true

@rpc("authority","call_remote","reliable")
func skill_snapshot(skills: Dictionary) -> void:
    if live_ui != null:
        live_ui.set_skills(skills)

const EXTRA_RECIPES := {
    "bandage": {"wood":1, "herb":2},
    "repair_kit": {"wood":3, "stone":2},
    "spear": {"wood":3, "stone":2},
    "bow": {"wood":4, "herb":2},
    "shield": {"wood":4, "stone":1},
    "arrow": {"wood":1, "stone":1}
}

func _try_craft_recipe(recipe_id: String) -> void:
    if recipe_id == "axe":
        _try_craft_axe()
    elif EXTRA_RECIPES.has(recipe_id) and own_id > 0:
        if multiplayer.is_server():
            _craft_consumable_on_server(own_id, recipe_id)
        else:
            request_craft_consumable.rpc_id(1, recipe_id)

@rpc("any_peer", "reliable")
func request_craft_consumable(recipe_id: String) -> void:
    if multiplayer.is_server():
        _craft_consumable_on_server(multiplayer.get_remote_sender_id(), recipe_id)

func _craft_consumable_on_server(id: int, recipe_id: String) -> bool:
    if not multiplayer.is_server() or not EXTRA_RECIPES.has(recipe_id) or not players.has(id) or int(player_health.get(id,0)) <= 0 or not _near_campfire(id):
        return false
    var cost: Dictionary = EXTRA_RECIPES[recipe_id]
    var before: Dictionary = player_inventories.get(id,_empty_inventory()).duplicate(true)
    for material in cost:
        if int(before.get(material,0)) < int(cost[material]):
            return false
    if int(before.get(recipe_id,0)) >= (40 if recipe_id == "arrow" else 1 if ["spear","bow","shield"].has(recipe_id) else 20):
        return false
    var inv := before.duplicate(true)
    for material in cost:
        inv[material] = int(inv.get(material,0)) - int(cost[material])
    inv[recipe_id] = int(inv.get(recipe_id,0)) + 1
    player_inventories[id] = inv
    if player_identity_keys.has(id):
        persistent_profiles[player_identity_keys[id]]["inventory"] = inv.duplicate(true)
    if not _save_world_state():
        player_inventories[id] = before
        if player_identity_keys.has(id):
            persistent_profiles[player_identity_keys[id]]["inventory"] = before.duplicate(true)
        return false
    if id == own_id:
        inventory_snapshot(inv)
    else:
        inventory_snapshot.rpc_id(id,inv)
    return true

func _try_use_consumable(recipe_id: String) -> void:
    if own_id <= 0 or not EXTRA_RECIPES.has(recipe_id):
        return
    if ["spear","bow","shield","arrow"].has(recipe_id):
        if recipe_id != "arrow":
            _try_equip_combat(recipe_id)
        return
    if multiplayer.is_server():
        _use_consumable_on_server(own_id,recipe_id)
    else:
        request_use_consumable.rpc_id(1,recipe_id)

@rpc("any_peer", "reliable")
func request_use_consumable(recipe_id: String) -> void:
    if multiplayer.is_server():
        _use_consumable_on_server(multiplayer.get_remote_sender_id(),recipe_id)

func _use_consumable_on_server(id: int, recipe_id: String) -> bool:
    if not multiplayer.is_server() or not EXTRA_RECIPES.has(recipe_id) or not players.has(id) or int(player_health.get(id,0)) <= 0:
        return false
    if recipe_id == "bandage" and int(player_health[id]) >= MAX_HEALTH:
        return false
    if recipe_id == "repair_kit" and (raid.phase != "night" or camp_target_id == 0 or camp_hp <= 0 or camp_hp >= CAMP_MAX_HP or not _near_campfire(id)):
        return false
    var before: Dictionary = player_inventories.get(id,_empty_inventory()).duplicate(true)
    if int(before.get(recipe_id,0)) <= 0:
        return false
    var inv := before.duplicate(true)
    inv[recipe_id] = int(inv[recipe_id])-1
    player_inventories[id] = inv
    if player_identity_keys.has(id):
        persistent_profiles[player_identity_keys[id]]["inventory"] = inv.duplicate(true)
    if not _save_world_state():
        player_inventories[id] = before
        if player_identity_keys.has(id):
            persistent_profiles[player_identity_keys[id]]["inventory"] = before.duplicate(true)
        return false
    if recipe_id == "bandage":
        player_health[id] = mini(MAX_HEALTH,int(player_health[id])+40)
        health_snapshot_for.rpc(id,int(player_health[id]))
        if id == own_id:
            health_snapshot(int(player_health[id]),MAX_HEALTH)
        else:
            health_snapshot.rpc_id(id,int(player_health[id]),MAX_HEALTH)
    else:
        camp_hp = mini(CAMP_MAX_HP,camp_hp+60)
        camp_health_snapshot.rpc(camp_hp,CAMP_MAX_HP)
    if id == own_id:
        inventory_snapshot(inv)
    else:
        inventory_snapshot.rpc_id(id,inv)
    return true

func _reset_resources() -> void:
    resource_remaining.clear()
    var world: Node3D = get_node("Eldoria_Forest")
    for entry in world.resources:
        resource_remaining[int(entry["id"])] = int(entry["amount"])
        world.set_resource_quantity(int(entry["id"]),int(entry["amount"]))


# Authoritative building: the client proposes a point, but server validates
# cost, distance, world bounds, terrain gradient and solid intersections.
func _show_build_feedback(message: String) -> void:
    _status(message)
    if live_ui != null:
        live_ui.show_message(message)
    if message.contains("built successfully") and mobile_build_mode:
        _set_mobile_build_mode(false)
    if build_feedback_label != null:
        build_feedback_label.text = message
        build_feedback_label.visible = true
        build_feedback_until = Time.get_ticks_msec() + 5200

@rpc("authority","call_remote","reliable")
func build_feedback(message: String) -> void:
    _show_build_feedback(message)

func _notify_build_result(id: int, message: String) -> void:
    if id == own_id:
        _show_build_feedback(message)
    elif connected_peers.has(id):
        build_feedback.rpc_id(id,message)

func _build_choice() -> String:
    return "tent" if build_selector != null and build_selector.selected == 1 else "campfire"

func _affordability_message(kind: String, inv: Dictionary) -> String:
    var needs := []
    for item in BUILDING_SCRIPT.COSTS[kind].keys():
        var required: int = BUILDING_SCRIPT.COSTS[kind][item]
        var have := int(inv.get(item,0))
        if required > have:
            needs.append("%d %s (have %d)" % [required,item,have])
    return "Need resources: " + ", ".join(needs)

func _find_build_target(kind: String, origin: Vector3, yaw: float) -> Vector3:
    # The old hard-coded point directly ahead failed silently near obstacles.
    # Try forward positions first, then gently fan out around the character.
    var world: Node3D = get_node("Eldoria_Forest")
    for radians in [0.0,-0.32,0.32,-0.64,0.64,-1.05,1.05,-1.57,1.57,3.14]:
        for distance in [3.5,4.4,5.3]:
            var forward := Vector3(0,0,-distance).rotated(Vector3.UP,yaw+radians)
            var spot := Vector3(origin.x+forward.x,0.0,origin.z+forward.z)
            spot.y = world.height_at(spot.x,spot.z)
            if _is_valid_build_spot(kind,spot,origin):
                return spot
    return Vector3.INF

func _mobile_ui() -> bool:
    return OS.get_name() == "Android" or OS.get_cmdline_user_args().has("--test-mobile-ui")

func _load_sound_preference() -> void:
    var cfg := ConfigFile.new()
    cfg.load("user://eldoria-sound.cfg")
    harvest_visuals.set_sound_enabled(bool(cfg.get_value("audio","enabled",true)))

func _toggle_sound() -> void:
    harvest_visuals.set_sound_enabled(not harvest_visuals.sound_enabled)
    if sound_button != null:
        sound_button.text = "Sound: ON" if harvest_visuals.sound_enabled else "Sound: OFF"
    var cfg := ConfigFile.new()
    cfg.set_value("audio","enabled",harvest_visuals.sound_enabled)
    cfg.save("user://eldoria-sound.cfg")

func _mobile_select_building(index: int) -> void:
    if build_selector != null:
        build_selector.select(index)
    if preview_enabled:
        _update_build_preview()

func _set_mobile_build_mode(enabled: bool) -> void:
    if is_dedicated:
        return
    mobile_build_mode = enabled
    if mobile_build_panel != null:
        # Fit even short landscape phone viewports; don't clip the selector.
        var screen_height := get_viewport().get_visible_rect().size.y
        mobile_build_panel.offset_top = maxf(-390.0,16.0-screen_height)
        mobile_build_panel.offset_bottom = mobile_build_panel.offset_top+185.0
        mobile_build_panel.visible = enabled and _mobile_ui() and live_ui == null
    if mobile_build_toggle != null:
        mobile_build_toggle.text = "Build: ON" if enabled else "Build mode"
        mobile_build_toggle.visible = _mobile_ui() and not enabled
    if enabled:
        if mobile_build_picker != null and build_selector != null:
            mobile_build_picker.select(build_selector.selected)
        preview_enabled = true
        _update_build_preview()
    else:
        _remove_preview()

func _mobile_place_building() -> void:
    if not mobile_build_mode:
        return
    _try_build()

func _toggle_build_preview() -> void:
    if is_dedicated:
        return
    preview_enabled = not preview_enabled
    if not preview_enabled:
        _remove_preview()
        _show_build_feedback("Build preview hidden.")
    else:
        _show_build_feedback("Build preview: green = valid, red = blocked or missing resources.")
        _update_build_preview()

func _remove_preview() -> void:
    if preview_actor != null and is_instance_valid(preview_actor):
        preview_actor.queue_free()
    preview_actor = null
    preview_enabled = false
    preview_kind = ""
    preview_spot = Vector3.INF
    preview_valid = false

func _update_build_preview() -> void:
    preview_last_update_msec = Time.get_ticks_msec()
    if not preview_enabled or is_dedicated or own_id == 0 or not players.has(own_id):
        if preview_actor != null and is_instance_valid(preview_actor):
            preview_actor.visible = false
        return
    var kind := _build_choice()
    var origin: Vector3 = players[own_id].position
    var spot := _find_build_target(kind,origin,input_driver.yaw)
    var has_spot := is_finite(spot.x)
    if not has_spot:
        # Red preview shows the attempted forward placement when blocked.
        var forward := Vector3(0,0,-3.5).rotated(Vector3.UP,input_driver.yaw)
        spot = origin + forward
        spot.y = get_node("Eldoria_Forest").height_at(spot.x,spot.z)
    var inv: Dictionary = player_inventories.get(own_id,{})
    var allowed := has_spot and BUILDING_SCRIPT.affordable(kind,inv)
    if preview_actor == null or not is_instance_valid(preview_actor) or preview_kind != kind:
        if preview_actor != null and is_instance_valid(preview_actor):
            preview_actor.queue_free()
        preview_actor = BUILDING_SCRIPT.new()
        preview_actor.name = "PlacementPreview"
        preview_actor.is_preview = true
        preview_actor.setup(0,kind,spot)
        add_child(preview_actor)
        preview_actor.set_visual_detail(graphics_quality == GRAPHICS_SCRIPT.HIGH)
        preview_kind = kind
    preview_spot = spot
    preview_valid = allowed
    preview_actor.position = spot
    preview_actor.visible = true
    if preview_actor.preview_valid != allowed:
        preview_actor.set_preview_valid(allowed)

func _try_craft_axe() -> void:
    if own_id == 0 or not players.has(own_id) or int(player_health.get(own_id, MAX_HEALTH)) <= 0:
        _show_build_feedback("Connect to the world before crafting.")
        return
    if multiplayer.is_server():
        _craft_axe_on_server(own_id)
    else:
        request_craft_axe.rpc_id(1)

@rpc("any_peer", "reliable")
func request_craft_axe() -> void:
    if not multiplayer.is_server():
        return
    _craft_axe_on_server(multiplayer.get_remote_sender_id())

func _near_campfire(id: int) -> bool:
    if not players.has(id):
        return false
    var actor: Vector3 = players[id].position
    for building in placed_buildings.values():
        if str(building.get("kind", "")) != "campfire":
            continue
        var location := Vector2(float(building["x"]), float(building["z"]))
        if location.distance_squared_to(Vector2(actor.x, actor.z)) <= 16.0:
            return true
    return false

# Only the authoritative host may spend resources, issue the unique axe,
# and commit persistent state before acknowledging successful crafting.
func _craft_axe_on_server(id: int) -> bool:
    if not multiplayer.is_server() or not players.has(id) or int(player_health.get(id, MAX_HEALTH)) <= 0:
        return false
    if not _near_campfire(id):
        _notify_build_result(id, "Craft the stone axe within 4 meters of a campfire.")
        return false
    var inv: Dictionary = player_inventories.get(id, _empty_inventory())
    if int(inv.get("axe", 0)) > 0:
        _notify_build_result(id, "Stone axe already crafted.")
        return false
    if int(inv.get("wood", 0)) < 2 or int(inv.get("stone", 0)) < 2:
        _notify_build_result(id, "Need 2 wood and 2 stone to craft an axe.")
        return false
    var before: Dictionary = inv.duplicate(true)
    inv["wood"] = int(inv["wood"]) - 2
    inv["stone"] = int(inv["stone"]) - 2
    inv["axe"] = 1
    player_inventories[id] = inv
    if player_identity_keys.has(id):
        persistent_profiles[player_identity_keys[id]]["inventory"] = inv.duplicate(true)
    if not _save_world_state():
        player_inventories[id] = before
        if player_identity_keys.has(id):
            persistent_profiles[player_identity_keys[id]]["inventory"] = before.duplicate(true)
        _notify_build_result(id, "Could not save crafted axe. No resources were spent.")
        return false
    if id == own_id:
        inventory_snapshot(inv)
    else:
        inventory_snapshot.rpc_id(id, inv)
    _notify_build_result(id, "Stone axe crafted! Select slot 4 to equip it.")
    return true

func _try_equip_axe(equip: bool) -> void:
    if own_id == 0 or not players.has(own_id):
        return
    if multiplayer.is_server():
        _set_axe_equipped_on_server(own_id, equip)
    else:
        request_equip_axe.rpc_id(1, equip)

@rpc("any_peer", "reliable")
func request_equip_axe(equip: bool) -> void:
    if multiplayer.is_server():
        _set_axe_equipped_on_server(multiplayer.get_remote_sender_id(), equip)

func _set_axe_equipped_on_server(id: int, equip: bool) -> bool:
    if not multiplayer.is_server() or not players.has(id):
        return false
    if equip and int(player_inventories.get(id, {}).get("axe", 0)) != 1:
        _notify_build_result(id, "Craft a stone axe before equipping.")
        return false
    equipped_axes[id] = equip
    # Keep the visual in sync for the host and every client. This does not
    # change server-side wood yield or trust equipment requests from clients.
    if players.has(id):
        players[id].set_axe_equipped(equip)
    axe_visual_snapshot.rpc(id, equip)
    if id == own_id:
        axe_equip_snapshot(equip)
    else:
        axe_equip_snapshot.rpc_id(id, equip)
    return true

@rpc("authority", "call_remote", "reliable")
func axe_equip_snapshot(equipped: bool) -> void:
    if live_ui != null:
        live_ui.set_equipped_axe(equipped)
    if players.has(own_id):
        players[own_id].set_axe_equipped(equipped)

@rpc("authority", "call_remote", "reliable")
func axe_visual_snapshot(id: int, equipped: bool) -> void:
    if players.has(id):
        players[id].set_axe_equipped(equipped)

func _try_build() -> void:
    if own_id == 0 or not players.has(own_id) or int(player_health.get(own_id, MAX_HEALTH)) <= 0:
        _show_build_feedback("Connect to the world before building.")
        return
    var kind := _build_choice()
    var inventory: Dictionary = player_inventories.get(own_id,{})
    if not BUILDING_SCRIPT.affordable(kind,inventory):
        _show_build_feedback(_affordability_message(kind,inventory))
        return
    var origin: Vector3 = players[own_id].position
    var target: Vector3
    if preview_enabled:
        # The confirmed building must use exactly the position just previewed.
        _update_build_preview()
        target = preview_spot if preview_valid else Vector3.INF
    else:
        target = _find_build_target(kind,origin,input_driver.yaw)
    if not is_finite(target.x):
        _show_build_feedback("No clear flat space nearby. Move away from obstacles.")
        return
    _show_build_feedback("Placing %s..." % kind)
    if multiplayer.is_server():
        _build_on_server(own_id,kind,target)
    else:
        request_build.rpc_id(1,kind,target)

@rpc("any_peer", "reliable")
func request_build(kind: String, spot: Vector3) -> void:
    if not multiplayer.is_server():
        return
    _build_on_server(multiplayer.get_remote_sender_id(),kind,spot)

func _is_valid_build_spot(kind: String, spot: Vector3, actor_pos: Vector3) -> bool:
    if not BUILDING_SCRIPT.is_valid_kind(kind):
        return false
    if not is_finite(spot.x) or not is_finite(spot.y) or not is_finite(spot.z):
        return false
    var flat := Vector2(spot.x,spot.z)
    var distance := flat.distance_to(Vector2(actor_pos.x,actor_pos.z))
    if distance < 2.1 or distance > 6.5 or flat.length() > 75.0:
        return false
    var world: Node3D = get_node("Eldoria_Forest")
    if absf(spot.y-world.height_at(spot.x,spot.z)) > 0.14:
        return false
    var radius: float = BUILDING_SCRIPT.RADII[kind]
    if world.collides_at(flat,radius+0.45):
        return false
    for other in placed_buildings.values():
        var existing := Vector2(float(other["x"]),float(other["z"]))
        if existing.distance_to(flat) < radius + float(BUILDING_SCRIPT.RADII[other["kind"]]) + 0.7:
            return false
    # Four corners need a reasonably level ground; no suspended shelters.
    for dir in [Vector2.RIGHT,Vector2.LEFT,Vector2.UP,Vector2.DOWN]:
        var offset: Vector2 = flat + dir*radius
        if absf(world.height_at(offset.x,offset.y)-spot.y) > 0.72:
            return false
    return true

func _build_on_server(id: int, kind: String, spot: Vector3) -> bool:
    if not multiplayer.is_server() or not players.has(id) or int(player_health.get(id, MAX_HEALTH)) <= 0:
        return false
    if placed_buildings.size() >= 300:
        _notify_build_result(id,"The world has reached its building limit.")
        return false
    if not _is_valid_build_spot(kind,spot,players[id].position):
        _notify_build_result(id,"Cannot build there. Find a clear, flat area.")
        return false
    var inv: Dictionary = player_inventories.get(id,{})
    if not BUILDING_SCRIPT.is_valid_kind(kind):
        _notify_build_result(id,"Unknown building type.")
        return false
    if not BUILDING_SCRIPT.affordable(kind,inv):
        _notify_build_result(id,_affordability_message(kind,inv))
        return false
    var old_inv := inv.duplicate(true)
    var id_new := next_building_id
    var record := {"kind":kind,"x":snappedf(spot.x,0.01),
        "z":snappedf(spot.z,0.01)}
    next_building_id += 1
    placed_buildings[id_new] = record
    for item in BUILDING_SCRIPT.COSTS[kind].keys():
        inv[item] = int(inv.get(item,0))-int(BUILDING_SCRIPT.COSTS[kind][item])
    player_inventories[id] = inv
    if player_identity_keys.has(id):
        var identity: String = player_identity_keys[id]
        persistent_profiles[identity]["inventory"] = inv.duplicate(true)
    if not _save_world_state():
        placed_buildings.erase(id_new)
        next_building_id = id_new
        player_inventories[id] = old_inv
        if player_identity_keys.has(id):
            persistent_profiles[player_identity_keys[id]]["inventory"] = old_inv.duplicate(true)
        _notify_build_result(id,"Could not save building. No resources were spent.")
        return false
    _place_building(id_new,record)
    _play_build_sound(record)
    for remote_peer in connected_peers.keys():
        building_created.rpc_id(int(remote_peer),id_new,record)
    if id == own_id:
        inventory_snapshot(inv)
    else:
        inventory_snapshot.rpc_id(id,inv)
    _notify_build_result(id,"%s built successfully!" % kind.capitalize())
    return true

func _clear_buildings() -> void:
    for node in building_nodes.values():
        if is_instance_valid(node):
            node.queue_free()
    building_nodes.clear()
    placed_buildings.clear()
    next_building_id = 1

func _load_buildings(saved: Dictionary) -> void:
    _clear_buildings()
    var world: Node3D = get_node("Eldoria_Forest")
    for key in saved.keys():
        var record: Dictionary = saved[key]
        var new_id := int(key)
        if not BUILDING_SCRIPT.is_valid_kind(str(record.get("kind",""))):
            continue
        var position := Vector3(float(record.get("x",0)),
            world.height_at(float(record.get("x",0)),float(record.get("z",0))),
            float(record.get("z",0)))
        _place_building(new_id,{"kind":record["kind"],"x":position.x,"z":position.z})

func _place_building(id: int, record: Dictionary) -> void:
    if placed_buildings.has(id) and building_nodes.has(id):
        return
    var kind: String = record["kind"]
    if not BUILDING_SCRIPT.is_valid_kind(kind):
        return
    var world: Node3D = get_node("Eldoria_Forest")
    var x := float(record["x"])
    var z := float(record["z"])
    var place := Vector3(x,world.height_at(x,z),z)
    var obj := BUILDING_SCRIPT.new()
    obj.setup(id,kind,place)
    obj.name = "Build_%d_%s" % [id,kind]
    add_child(obj)
    obj.set_visual_detail(graphics_quality == GRAPHICS_SCRIPT.HIGH)
    building_nodes[id] = obj
    placed_buildings[id] = {"kind":kind,"x":x,"z":z}
    next_building_id = maxi(next_building_id,id+1)

@rpc("authority","call_remote","reliable")
func building_snapshot(snapshot: Dictionary) -> void:
    _load_buildings(snapshot)

@rpc("authority","call_remote","reliable")
func building_created(id: int, record: Dictionary) -> void:
    _place_building(id,record)
    _play_build_sound(record)

func _apply_building_detail_quality() -> void:
    if ambience != null:
        ambience.set_high_detail(graphics_quality == GRAPHICS_SCRIPT.HIGH)
    for node in building_nodes.values():
        if is_instance_valid(node):
            node.set_visual_detail(graphics_quality == GRAPHICS_SCRIPT.HIGH)
    if is_instance_valid(preview_actor):
        preview_actor.set_visual_detail(graphics_quality == GRAPHICS_SCRIPT.HIGH)

func _play_build_sound(record: Dictionary) -> void:
    if harvest_visuals == null:
        return
    var world: Node3D = get_node("Eldoria_Forest")
    var x := float(record["x"])
    var z := float(record["z"])
    var position := Vector3(x,world.height_at(x,z),z)
    harvest_visuals.play_build_effect(str(record.get("kind","")), position)
    harvest_visuals.play_sound("build", position)

func _try_gather() -> void:
    if own_id == 0 or not players.has(own_id) or int(player_health.get(own_id, MAX_HEALTH)) <= 0:
        return
    var world: Node3D = get_node("Eldoria_Forest")
    var target: int = _aimed_gather_resource()
    if target < 0:
        _status("Подойдите к ресурсу на 2,7 м и повернитесь к нему.")
        return
    if multiplayer.is_server():
        _gather_on_server(own_id, target)
    else:
        request_gather.rpc_id(1,target)

@rpc("any_peer", "reliable")
func request_gather(resource_id: int) -> void:
    if not multiplayer.is_server():
        return
    _gather_on_server(multiplayer.get_remote_sender_id(),resource_id)

func _gather_on_server(player_id: int, resource_id: int) -> bool:
    if not multiplayer.is_server() or not players.has(player_id) or int(player_health.get(player_id, MAX_HEALTH)) <= 0:
        return false
    var world: Node3D = get_node("Eldoria_Forest")
    var entry: Dictionary = world.resource_by_id(resource_id)
    if entry.is_empty() or int(resource_remaining.get(resource_id,0)) <= 0:
        return false
    var pos: Vector3 = players[player_id].position
    var spot: Vector3 = entry["pos"]
    if Vector2(pos.x,pos.z).distance_squared_to(Vector2(spot.x,spot.z)) > 2.7*2.7:
        return false
    if absf(pos.y - spot.y) > 4.0:
        return false
    var now := Time.get_ticks_msec()
    if last_gather_at.has(player_id) and now-int(last_gather_at[player_id]) < 280:
        return false
    last_gather_at[player_id] = now
    var kind: String = entry["kind"]
    if kind not in ["wood","stone","herb"]:
        return false
    var has_equipped_axe: bool = bool(equipped_axes.get(player_id, false)) and int(player_inventories.get(player_id, {}).get("axe", 0)) == 1
    var chop_amount := 2 if kind == "wood" and has_equipped_axe else 1
    chop_amount = mini(chop_amount, int(resource_remaining[resource_id]))
    resource_remaining[resource_id] = int(resource_remaining[resource_id])-chop_amount
    world.set_resource_quantity(resource_id,int(resource_remaining[resource_id]))
    if not player_inventories.has(player_id):
        player_inventories[player_id] = _empty_inventory()
    var inventory: Dictionary = player_inventories[player_id]
    inventory[kind] = int(inventory.get(kind,0))+chop_amount
    player_inventories[player_id] = inventory
    # Persist the resource depletion and private inventory together before
    # broadcasting success; revert the in-memory action if disk write fails.
    if player_identity_keys.has(player_id):
        var key: String = player_identity_keys[player_id]
        persistent_profiles[key]["inventory"] = inventory.duplicate(true)
    if not _save_world_state():
        resource_remaining[resource_id] = int(resource_remaining[resource_id])+chop_amount
        world.set_resource_quantity(resource_id,int(resource_remaining[resource_id]))
        inventory[kind] = int(inventory[kind])-chop_amount
        player_inventories[player_id] = inventory
        if player_identity_keys.has(player_id):
            persistent_profiles[player_identity_keys[player_id]]["inventory"] = inventory.duplicate(true)
        return false
    for remote_peer in connected_peers.keys():
        resource_changed.rpc_id(int(remote_peer),resource_id,int(resource_remaining[resource_id]))
    if own_id == player_id:
        inventory_snapshot(inventory)
    else:
        inventory_snapshot.rpc_id(player_id,inventory)
    for remote_peer in connected_peers.keys():
        gather_effect.rpc_id(int(remote_peer),player_id,kind,resource_id,
            int(resource_remaining[resource_id]),pos)
    if own_id == player_id:
        _gather_effect_local(player_id,kind,resource_id,
            int(resource_remaining[resource_id]),pos)
    return true

@rpc("authority", "call_remote", "reliable")
func resource_snapshot(snapshot: Dictionary) -> void:
    var world: Node3D = get_node("Eldoria_Forest")
    for id in snapshot.keys():
        var number := int(id)
        if not world.resource_by_id(number).is_empty():
            resource_remaining[number] = maxi(0,int(snapshot[id]))
            world.set_resource_quantity(number,int(resource_remaining[number]))

@rpc("authority", "call_remote", "reliable")
func resource_changed(resource_id: int, amount: int) -> void:
    var world: Node3D = get_node("Eldoria_Forest")
    if not world.resource_by_id(resource_id).is_empty():
        resource_remaining[resource_id] = maxi(0,amount)
        world.set_resource_quantity(resource_id,int(resource_remaining[resource_id]))

@rpc("authority", "call_remote", "reliable")
func inventory_snapshot(inventory: Dictionary) -> void:
    if own_id == 0 or not players.has(own_id):
        return
    var validated := _empty_inventory()
    for kind in validated.keys():
        validated[kind] = clampi(int(inventory.get(kind,0)),0,1 if ["axe","spear","bow","shield"].has(kind) else (40 if kind == "arrow" else 20 if EXTRA_RECIPES.has(kind) else 1000000))
    player_inventories[own_id] = validated
    if live_ui != null:
        live_ui.set_inventory(validated)
        if int(validated.get("axe", 0)) == 0:
            live_ui.set_equipped_axe(false)
    _refresh_gather_hud()

@rpc("authority", "call_remote", "reliable")
func gather_effect(player_id: int, kind: String, resource_id: int, amount: int,
        actor_position: Vector3) -> void:
    _gather_effect_local(player_id,kind,resource_id,amount,actor_position)

func _gather_effect_local(player_id: int, kind: String, resource_id: int, amount: int,
        actor_position: Vector3) -> void:
    var world: Node3D = get_node("Eldoria_Forest")
    var entry: Dictionary = world.resource_by_id(resource_id)
    if players.has(player_id):
        if not entry.is_empty():
            players[player_id].face_interaction(entry["pos"])
        players[player_id].gather(kind)
    if harvest_visuals != null and not entry.is_empty():
        harvest_visuals.play_pickup(kind,entry["pos"])
        if kind == "wood" and amount == 0:
            harvest_visuals.play_tree_fall(resource_id,world,actor_position)
    if player_id == own_id:
        _status("Collected %s" % kind)

func _refresh_gather_hud() -> void:
    if inventory_label == null or resource_label == null:
        return
    var inv: Dictionary = player_inventories.get(own_id,_empty_inventory())
    inventory_label.text = "Wood: %d | Stone: %d | Herbs: %d | Axe: %s" % [int(inv.get("wood",0)),int(inv.get("stone",0)),int(inv.get("herb",0)),"YES" if int(inv.get("axe",0))>0 else "NO"]
    if own_id == 0 or not players.has(own_id):
        resource_label.text = "Near: none"
        _set_gather_target(-1)
        return
    var world: Node3D = get_node("Eldoria_Forest")
    var resource_id: int = _aimed_gather_resource()
    _set_gather_target(resource_id)
    if resource_id < 0:
        resource_label.text = "Near: none"
    else:
        var entry: Dictionary = world.resource_by_id(resource_id)
        resource_label.text = "Цель: %s (%d) — F / СБОР" % [
            String(entry["kind"]),int(resource_remaining.get(resource_id,0))]

func _aimed_gather_resource() -> int:
    if own_id <= 0 or not players.has(own_id):
        return -1
    var world: Node3D = get_node("Eldoria_Forest")
    var facing := Vector3.FORWARD.rotated(Vector3.UP,input_driver.yaw)
    return RESOURCE_TARGETING.choose(world.resources,players[own_id].position,
        facing,resource_remaining)

func _set_gather_target(resource_id: int) -> void:
    selected_resource_id = resource_id
    if resource_target_marker != null:
        resource_target_marker.visible = resource_id > 0
    if resource_id <= 0:
        if live_ui != null:
            live_ui.set_gather_target("",0)
        return
    var entry: Dictionary = get_node("Eldoria_Forest").resource_by_id(resource_id)
    if entry.is_empty():
        return
    if resource_target_marker != null:
        resource_target_marker.position = Vector3(entry["pos"].x,
            entry["pos"].y+0.20,entry["pos"].z)
        var label: Label3D = resource_target_marker.get_node("GatherLabel")
        label.text = {"wood":"ДЕРЕВО","stone":"КАМЕНЬ","herb":"РАСТЕНИЕ"}.get(
            str(entry["kind"]),"РЕСУРС")
        # Large trees should display their selection overhead.
        label.position.y = 2.6 if entry["kind"] == "wood" else 1.1
    if live_ui != null:
        live_ui.set_gather_target(str(entry["kind"]),
            int(resource_remaining.get(resource_id,0)))

func _try_jump() -> void:
    if own_id == 0 or not players.has(own_id) or int(player_health.get(own_id, MAX_HEALTH)) <= 0:
        return
    var now := Time.get_ticks_msec()
    if jump_request_msec > 0 and now - jump_request_msec < JUMP_MOTION.COOLDOWN_MSEC:
        return
    if client_jump_start_msec != 0:
        return
    jump_request_msec = now
    if multiplayer.is_server():
        _accept_jump(own_id)
    else:
        request_jump.rpc_id(1)

@rpc("any_peer", "reliable")
func request_jump() -> void:
    if not multiplayer.is_server():
        return
    _accept_jump(multiplayer.get_remote_sender_id())

func _accept_jump(id: int) -> void:
    if not players.has(id) or int(player_health.get(id, MAX_HEALTH)) <= 0:
        return
    var now := Time.get_ticks_msec()
    if server_jump_times.has(id) and now-int(server_jump_times[id]) < JUMP_MOTION.COOLDOWN_MSEC:
        return
    var world: Node3D = get_node("Eldoria_Forest")
    var pos: Vector3 = players[id].position
    if absf(pos.y-world.height_at(pos.x,pos.z)-1.0) > 0.22:
        return
    server_jump_times[id] = now
    if id == own_id:
        _jump_started_local(id)
    for remote_peer in connected_peers.keys():
        jump_started.rpc_id(int(remote_peer),id)

@rpc("authority", "call_remote", "reliable")
func jump_started(id: int) -> void:
    _jump_started_local(id)

func _jump_started_local(id: int) -> void:
    if not players.has(id):
        return
    var now := Time.get_ticks_msec()
    players[id].set_meta("jump_start_msec", now)
    players[id].start_jump()
    if id == own_id:
        client_jump_start_msec = now

func _interact() -> void:
    if own_id == 0 or not players.has(own_id):
        return
    if multiplayer.is_server():
        _apply_emote(own_id)
        broadcast_emote.rpc(own_id)
    else:
        request_emote.rpc_id(1)

@rpc("any_peer", "reliable")
func request_emote() -> void:
    if not multiplayer.is_server():
        return
    var id := multiplayer.get_remote_sender_id()
    if not players.has(id):
        return
    _apply_emote(id)
    broadcast_emote.rpc(id)

@rpc("authority", "call_remote", "reliable")
func broadcast_emote(id: int) -> void:
    _apply_emote(id)

func _apply_emote(id: int) -> void:
    if not players.has(id):
        return
    emote_counts[id] = int(emote_counts.get(id, 0)) + 1
    players[id].celebrate()
    _status("Player %d cheered (%d)" % [id, emote_counts[id]])

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    if event.keycode == KEY_F9 and performance_overlay != null:
        performance_overlay.toggle()
        get_viewport().set_input_as_handled()
        return
    if live_ui != null and not live_ui.active_panel.is_empty() and event.keycode != KEY_F11:
        return
    if event.keycode == KEY_F11 and OS.get_name() != "Android":
        _toggle_fullscreen()
    elif event.keycode == KEY_E:
        _interact()
    elif event.keycode == KEY_SPACE:
        _try_jump()
    elif event.keycode == KEY_F:
        _try_gather()
    elif event.keycode == KEY_B:
        _try_build()
    elif event.keycode == KEY_C:
        _try_craft_axe()
    elif event.keycode == KEY_V:
        _toggle_build_preview()
    elif event.keycode == KEY_J:
        _try_attack()
    elif event.keycode == KEY_Q:
        _try_hero_ability()
    elif event.keycode == KEY_G:
        _cycle_mage_spell()
    elif event.keycode == KEY_R:
        _try_repair_camp()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and not is_dedicated and (
            live_ui == null or live_ui.active_panel.is_empty()):
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            input_driver.change_zoom(-1.3)
            get_viewport().set_input_as_handled()
            return
        if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            input_driver.change_zoom(1.3)
            get_viewport().set_input_as_handled()
            return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        if (live_ui == null or live_ui.active_panel.is_empty()) and not is_dedicated:
            _try_attack()

func _toggle_fullscreen() -> void:
    DISPLAY_SCRIPT.toggle_fullscreen()

func _live_build(kind: String) -> void:
    if kind != "campfire" and kind != "tent":
        return
    if build_selector != null:
        build_selector.select(0 if kind == "campfire" else 1)
    _try_build()

func _live_preview(kind: String) -> void:
    if kind != "campfire" and kind != "tent":
        return
    if build_selector != null:
        build_selector.select(0 if kind == "campfire" else 1)
    if not preview_enabled:
        _toggle_build_preview()
    else:
        _update_build_preview()

func _live_action(kind: String) -> void:
    match kind:
        "spear", "bow", "shield":
            _try_equip_combat(kind)
        "bandage":
            _try_use_consumable("bandage")
        "repair_kit":
            _try_use_consumable("repair_kit")
        "repair":
            _try_repair_camp()
        "heal":
            _try_heal_at_camp()
        "gather":
            _try_gather()
        "jump":
            _try_jump()
        "sprint":
            sprint_active = not sprint_active
        "reconnect":
            _disconnect()
            _fetch_server_config()
        "disconnect":
            _disconnect()
        "quality":
            graphics_quality = GRAPHICS_SCRIPT.HIGH if graphics_quality == GRAPHICS_SCRIPT.LOW else GRAPHICS_SCRIPT.LOW
            GRAPHICS_SCRIPT.apply(graphics_quality, sunlight, foliage)
            get_node("Eldoria_Forest").apply_detail_quality(graphics_quality == GRAPHICS_SCRIPT.HIGH)
            _apply_building_detail_quality()
            harvest_visuals.set_combat_detail(graphics_quality == GRAPHICS_SCRIPT.HIGH)
            if live_ui != null:
                live_ui.show_message("Graphics: %s" % ("Low" if graphics_quality == GRAPHICS_SCRIPT.LOW else "High"))
        "sound":
            _toggle_sound()
        "telemetry":
            _toggle_telemetry()
        "performance_debug":
            if performance_overlay != null:
                performance_overlay.toggle()
        "avatar":
            _choose_avatar((selected_avatar + 1) % AVATAR_PROFILE.LABELS.size())
        "preview":
            _toggle_build_preview()
