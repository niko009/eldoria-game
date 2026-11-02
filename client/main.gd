extends Node3D

# One Godot scene, one replication protocol and one set of mechanics for all exports.
# The current ENet session is an MVP transport, not the planned authoritative .NET protocol.
const PORT := 7777
const WEBSOCKET_PORT := 7788
const MAX_PLAYERS := 10
const INPUT_SCRIPT := preload("res://platform_input.gd")
const JOYSTICK_SCRIPT := preload("res://mobile_joystick.gd")
const WORLD_SAVE_SCRIPT := preload("res://world_save.gd")
const POSTGRES_WORLD_STORE_SCRIPT := preload("res://postgres_world_store.gd")
const BUILDING_SCRIPT := preload("res://building_object.gd")
const HARVEST_VFX_SCRIPT := preload("res://harvest_vfx.gd")
const DISPLAY_SCRIPT := preload("res://display_settings.gd")
const GRAPHICS_SCRIPT := preload("res://graphics_profile.gd")
const FOREST_SCRIPT := preload("res://forest_world.gd")
const ACTOR_SCRIPT := preload("res://animated_actor.gd")
const AVATAR_PROFILE := preload("res://avatar_profile.gd")
const JUMP_MOTION := preload("res://jump_motion.gd")
const UPDATE_SCRIPT := preload("res://update_manager.gd")
const MOVE_SPEED := 6.0
const CLIENT_VERSION := "0.5.0"
# Published v0.5.0 multiplayer client. Development builds may toggle this to true.
# TASK-015 development build: do not auto-connect or update against live v0.5.0.
const DEVELOPMENT_BUILD := true
const SERVER_CONFIG_URL := "https://bacus.dev/projects/eldoria/server.json"

var peer: MultiplayerPeer = ENetMultiplayerPeer.new()
var players := {}
var player_choices := {}
var resource_remaining := {}
var player_inventories := {}
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
var camera: Camera3D
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
var sunlight: DirectionalLight3D
var foliage: Array[SphereMesh] = []
var graphics_quality := 1

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
    harvest_visuals = HARVEST_VFX_SCRIPT.new()
    harvest_visuals.name = "HarvestVisuals"
    add_child(harvest_visuals)
    _reset_resources()
    GRAPHICS_SCRIPT.apply(graphics_quality, sunlight, foliage)
    get_node("Eldoria_Forest").apply_detail_quality(graphics_quality == GRAPHICS_SCRIPT.HIGH)
    if not is_dedicated:
        selected_avatar = AVATAR_PROFILE.read_choice()
    input_driver = INPUT_SCRIPT.new()
    add_child(input_driver)
    if not is_dedicated:
        _ui()
        _init_updater()
        # Exported Windows/Android builds discover the server automatically.
        # SceneTree test harnesses supply CLI user args and trigger discovery explicitly.
        if OS.get_cmdline_user_args().is_empty():
            if DEVELOPMENT_BUILD:
                _status("DEV TASK-015: connect to your test server only. Live v0.5.0 unchanged.")
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
    mobile_controls.visible = OS.get_name() == "Android"
    mobile_controls.moved.connect(input_driver.set_joystick)
    player_ui.add_child(mobile_controls)

    var sprint_button := Button.new()
    sprint_button.text = "Sprint: OFF"
    sprint_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    sprint_button.offset_left = -190
    sprint_button.offset_top = -225
    sprint_button.offset_right = -24
    sprint_button.offset_bottom = -169
    sprint_button.visible = OS.get_name() == "Android"
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
    gather_mobile.visible = OS.get_name() == "Android"
    gather_mobile.pressed.connect(_try_gather)
    player_ui.add_child(gather_mobile)

    var build_mobile := Button.new()
    build_mobile.text = "Build"
    build_mobile.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    build_mobile.offset_left = -340
    build_mobile.offset_top = -240
    build_mobile.offset_right = -210
    build_mobile.offset_bottom = -177
    build_mobile.visible = OS.get_name() == "Android"
    build_mobile.pressed.connect(_try_build)
    player_ui.add_child(build_mobile)
    var preview_mobile := Button.new()
    preview_mobile.text = "Preview"
    preview_mobile.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    preview_mobile.offset_left = -190
    preview_mobile.offset_top = -300
    preview_mobile.offset_right = -24
    preview_mobile.offset_bottom = -243
    preview_mobile.visible = OS.get_name() == "Android"
    preview_mobile.pressed.connect(_toggle_build_preview)
    player_ui.add_child(preview_mobile)
    var jump_button := Button.new()
    jump_button.text = "Jump"
    jump_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    jump_button.offset_left = -340
    jump_button.offset_top = -88
    jump_button.offset_right = -210
    jump_button.offset_bottom = -24
    jump_button.visible = OS.get_name() == "Android"
    jump_button.pressed.connect(_try_jump)
    player_ui.add_child(jump_button)

    var touch_emote := Button.new()
    touch_emote.text = "Wave"
    touch_emote.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    touch_emote.offset_left = -145
    touch_emote.offset_top = -86
    touch_emote.offset_right = -24
    touch_emote.offset_bottom = -24
    touch_emote.visible = OS.get_name() == "Android"
    touch_emote.pressed.connect(_interact)
    player_ui.add_child(touch_emote)

    var quality_button := Button.new()
    quality_button.text = "Graphics: Low" if graphics_quality == GRAPHICS_SCRIPT.LOW else "Graphics: High"
    if OS.get_name() == "Android":
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
        quality_button.text = "Graphics: High" if graphics_quality == GRAPHICS_SCRIPT.HIGH else "Graphics: Low"
    )

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
    if not _configure_world_persistence():
        push_error("Eldoria save data invalid; refusing to host")
        peer.close()
        multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
        if is_dedicated:
            get_tree().quit(1)
        return
    if is_dedicated:
        print("ELDORIA DEDICATED SERVER READY %s" % ("WS TCP 7788" if is_websocket_host else "UDP 7777"))
        return
    own_id = multiplayer.get_unique_id()
    _spawn(own_id, Vector3(0, 1, 0), selected_avatar)
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
    player_identity_keys.erase(id)
    _remove_actor(id)
    # SceneMultiplayer propagates peer_disconnected to all clients already.
    # No extra RPC: a peer may have closed its ENet channel during this signal.

@rpc("authority", "call_remote", "reliable")
func despawn_remote(id: int) -> void:
    _remove_actor(id)

func _remove_actor(id: int) -> void:
    if players.has(id):
        players[id].queue_free()
        players.erase(id)
    emote_counts.erase(id)
    player_choices.erase(id)
    player_inventories.erase(id)
    last_gather_at.erase(id)
    last_remote_ticks.erase(id)
    server_jump_times.erase(id)

func _clear_session() -> void:
    own_id = 0
    last_sent_position = Vector3.INF
    send_accumulator = 0.0
    connected_peers.clear()
    _remove_preview()
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
        persistent_profiles[identity_hash] = {"avatar":validated,"inventory":_empty_inventory()}
        if not _save_world_state():
            persistent_profiles.erase(identity_hash)
            player_identity_keys.erase(id)
            multiplayer.multiplayer_peer.disconnect_peer(id)
            return
    for existing in players:
        spawn_remote.rpc_id(id, existing, players[existing].position, int(player_choices.get(existing, 0)))
    var pos := Vector3(float(players.size() * 3), 1, 0)
    _spawn(id, pos, validated)
    player_inventories[id] = _empty_inventory()
    if not identity_hash.is_empty() and persistent_profiles.has(identity_hash):
        player_inventories[id] = persistent_profiles[identity_hash]["inventory"].duplicate(true)
    spawn_remote.rpc(id, pos, validated)
    resource_snapshot.rpc_id(id, resource_remaining)
    inventory_snapshot.rpc_id(id, player_inventories[id])
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
        if avatar_selector != null:
            avatar_selector.select(valid_choice)
        if OS.get_cmdline_user_args().is_empty():
            AVATAR_PROFILE.save_choice(valid_choice)
    emote_counts[id] = 0

func _choose_avatar(choice: int) -> void:
    if not AVATAR_PROFILE.valid(choice):
        return
    selected_avatar = choice
    if AVATAR_PROFILE.save_choice(choice) != OK:
        _status("Could not save avatar preference.")
    if own_id == 0:
        return
    if multiplayer.is_server():
        if _set_avatar_for_peer(own_id, choice):
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
    if _set_avatar_for_peer(peer_id, choice):
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
    if id == own_id and avatar_selector != null:
        avatar_selector.select(choice)
    return true


func _physics_process(delta: float) -> void:
    if is_dedicated or own_id == 0 or not players.has(own_id):
        return
    if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
        return
    var axis: Vector2 = input_driver.get_move_vector()
    var fast := sprint_active or Input.is_key_pressed(KEY_SHIFT)
    var speed := MOVE_SPEED * (1.5 if fast else 1.0)
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
    var focus: Vector3 = players[own_id].position + Vector3(0, 1.6, 0)
    var offset := Vector3(0, -sin(input_driver.pitch) * 13.0, cos(input_driver.pitch) * 13.0)
    var target: Vector3 = focus + offset.rotated(Vector3.UP, input_driver.yaw)
    var smoothed: Vector3 = camera.position.lerp(target, minf(1.0, delta * 7.0))
    camera.position = world.camera_safe_target(focus, smoothed)
    camera.look_at(focus, Vector3.UP)
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
    if fps_label == null:
        return
    fps_accumulator += delta
    if fps_accumulator >= 0.65:
        fps_accumulator = 0.0
        fps_label.text = "FPS: %d | %s" % [Engine.get_frames_per_second(), "Low" if graphics_quality == GRAPHICS_SCRIPT.LOW else "High"]
    _refresh_gather_hud()
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
    if players[id].airborne and int(Time.get_ticks_msec()-int(players[id].get_meta("jump_start_msec",0))) > int(JUMP_MOTION.DURATION*1000.0):
        players[id].finish_jump()


# The server owns resource quantities and player inventories.
# This is an in-memory prototype; a permanent world will require persistence.
func _empty_inventory() -> Dictionary:
    return {"wood":0, "stone":0, "herb":0}

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
        preview_kind = kind
    preview_spot = spot
    preview_valid = allowed
    preview_actor.position = spot
    preview_actor.visible = true
    if preview_actor.preview_valid != allowed:
        preview_actor.set_preview_valid(allowed)

func _try_build() -> void:
    if own_id == 0 or not players.has(own_id):
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
    if not multiplayer.is_server() or not players.has(id):
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
    building_nodes[id] = obj
    placed_buildings[id] = {"kind":kind,"x":x,"z":z}
    next_building_id = maxi(next_building_id,id+1)

@rpc("authority","call_remote","reliable")
func building_snapshot(snapshot: Dictionary) -> void:
    _load_buildings(snapshot)

@rpc("authority","call_remote","reliable")
func building_created(id: int, record: Dictionary) -> void:
    _place_building(id,record)

func _try_gather() -> void:
    if own_id == 0 or not players.has(own_id):
        return
    var world: Node3D = get_node("Eldoria_Forest")
    var target: int = world.nearest_resource(players[own_id].position, 2.7, resource_remaining)
    if target < 0:
        _status("No resource in range. Approach a tree, rock or flower.")
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
    if not multiplayer.is_server() or not players.has(player_id):
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
    resource_remaining[resource_id] = int(resource_remaining[resource_id])-1
    world.set_resource_quantity(resource_id,int(resource_remaining[resource_id]))
    if not player_inventories.has(player_id):
        player_inventories[player_id] = _empty_inventory()
    var inventory: Dictionary = player_inventories[player_id]
    inventory[kind] = int(inventory.get(kind,0))+1
    player_inventories[player_id] = inventory
    # Persist the resource depletion and private inventory together before
    # broadcasting success; revert the in-memory action if disk write fails.
    if player_identity_keys.has(player_id):
        var key: String = player_identity_keys[player_id]
        persistent_profiles[key]["inventory"] = inventory.duplicate(true)
    if not _save_world_state():
        resource_remaining[resource_id] = int(resource_remaining[resource_id])+1
        world.set_resource_quantity(resource_id,int(resource_remaining[resource_id]))
        inventory[kind] = int(inventory[kind])-1
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
        validated[kind] = clampi(int(inventory.get(kind,0)),0,1000000)
    player_inventories[own_id] = validated
    _refresh_gather_hud()

@rpc("authority", "call_remote", "reliable")
func gather_effect(player_id: int, kind: String, resource_id: int, amount: int,
        actor_position: Vector3) -> void:
    _gather_effect_local(player_id,kind,resource_id,amount,actor_position)

func _gather_effect_local(player_id: int, kind: String, resource_id: int, amount: int,
        actor_position: Vector3) -> void:
    if players.has(player_id):
        players[player_id].gather(kind)
    if harvest_visuals != null:
        var world: Node3D = get_node("Eldoria_Forest")
        var entry: Dictionary = world.resource_by_id(resource_id)
        if not entry.is_empty():
            harvest_visuals.play_pickup(kind,entry["pos"])
            if kind == "wood" and amount == 0:
                harvest_visuals.play_tree_fall(resource_id,world,actor_position)
    if player_id == own_id:
        _status("Collected %s" % kind)

func _refresh_gather_hud() -> void:
    if inventory_label == null or resource_label == null:
        return
    var inv: Dictionary = player_inventories.get(own_id,_empty_inventory())
    inventory_label.text = "Wood: %d | Stone: %d | Herbs: %d" % [int(inv.get("wood",0)),int(inv.get("stone",0)),int(inv.get("herb",0))]
    if own_id == 0 or not players.has(own_id):
        resource_label.text = "Near: none"
        return
    var world: Node3D = get_node("Eldoria_Forest")
    var resource_id: int = world.nearest_resource(players[own_id].position,2.7,resource_remaining)
    if resource_id < 0:
        resource_label.text = "Near: none"
    else:
        var entry: Dictionary = world.resource_by_id(resource_id)
        resource_label.text = "Nearby: %s (%d left) — F / Gather" % [String(entry["kind"]),int(resource_remaining.get(resource_id,0))]

func _try_jump() -> void:
    if own_id == 0 or not players.has(own_id):
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
    if not players.has(id):
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
    elif event.keycode == KEY_V:
        _toggle_build_preview()

func _toggle_fullscreen() -> void:
    DISPLAY_SCRIPT.toggle_fullscreen()
