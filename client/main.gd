extends Node3D

# One Godot scene, one replication protocol and one set of mechanics for all exports.
# The current ENet session is an MVP transport, not the planned authoritative .NET protocol.
const PORT := 7777
const WEBSOCKET_PORT := 7788
const MAX_PLAYERS := 10
const INPUT_SCRIPT := preload("res://platform_input.gd")
const DISPLAY_SCRIPT := preload("res://display_settings.gd")
const GRAPHICS_SCRIPT := preload("res://graphics_profile.gd")
const FOREST_SCRIPT := preload("res://forest_world.gd")
const UPDATE_SCRIPT := preload("res://update_manager.gd")
const MOVE_SPEED := 6.0
const CLIENT_VERSION := "0.2.1"
const SERVER_CONFIG_URL := "https://bacus.dev/projects/eldoria/server.json"

var peer: MultiplayerPeer = ENetMultiplayerPeer.new()
var players := {}
var emote_counts := {}
var own_id := 0
var is_dedicated := false
var is_websocket_host := false
var connected_peers := {}
var updater: Node
var update_button: Button
var update_info: Label
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
    GRAPHICS_SCRIPT.apply(graphics_quality, sunlight, foliage)
    input_driver = INPUT_SCRIPT.new()
    add_child(input_driver)
    if not is_dedicated:
        _ui()
        _init_updater()
        # Exported Windows/Android builds discover the server automatically.
        # SceneTree test harnesses supply CLI user args and trigger discovery explicitly.
        if OS.get_cmdline_user_args().is_empty():
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
    var title := Label.new()
    title.text = "ELDORIA / CROSS-PLATFORM PRE-ALPHA"
    panel.add_child(title)
    # Hidden compatibility entry retained for legacy E2E and developer use.
    # Exported players never have to type a server address.
    ip_input = LineEdit.new()
    ip_input.text = "127.0.0.1"
    ip_input.visible = false
    panel.add_child(ip_input)
    var connect_button := Button.new()
    connect_button.text = "Connect / Retry"
    connect_button.pressed.connect(_fetch_server_config)
    panel.add_child(connect_button)
    var disconnect := Button.new()
    disconnect.text = "Disconnect"
    disconnect.pressed.connect(_disconnect)
    panel.add_child(disconnect)
    var emote := Button.new()
    emote.text = "Wave (E)"
    emote.pressed.connect(_interact)
    panel.add_child(emote)
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

    mobile_controls = Control.new()
    mobile_controls.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    mobile_controls.offset_left = 24
    mobile_controls.offset_top = -228
    mobile_controls.offset_right = 270
    mobile_controls.offset_bottom = -16
    mobile_controls.visible = OS.get_name() == "Android"
    player_ui.add_child(mobile_controls)
    for entry in [["▲", Vector2(78, 0), Vector2(0, -1)], ["▼", Vector2(78, 128), Vector2(0, 1)], ["◀", Vector2(0, 64), Vector2(-1, 0)], ["▶", Vector2(156, 64), Vector2(1, 0)]]:
        var button := Button.new()
        button.text = entry[0]
        button.position = entry[1]
        button.custom_minimum_size = Vector2(70, 60)
        button.add_theme_font_size_override("font_size", 23)
        button.button_down.connect(func() -> void: input_driver.press_direction(entry[2]))
        button.button_up.connect(func() -> void: input_driver.release_direction(entry[2]))
        mobile_controls.add_child(button)

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

    if OS.get_name() == "Android":
        var quality_button := Button.new()
        quality_button.text = "Graphics: Low"
        quality_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
        quality_button.offset_left = -190
        quality_button.offset_top = -155
        quality_button.offset_right = -24
        quality_button.offset_bottom = -100
        quality_button.pressed.connect(func() -> void:
            graphics_quality = GRAPHICS_SCRIPT.HIGH if graphics_quality == GRAPHICS_SCRIPT.LOW else GRAPHICS_SCRIPT.LOW
            GRAPHICS_SCRIPT.apply(graphics_quality, sunlight, foliage)
            quality_button.text = "Graphics: High" if graphics_quality == GRAPHICS_SCRIPT.HIGH else "Graphics: Low"
        )
        player_ui.add_child(quality_button)

func _init_updater() -> void:
    updater = UPDATE_SCRIPT.new()
    updater.current_version = CLIENT_VERSION
    add_child(updater)
    updater.update_available.connect(_on_update_available)
    updater.update_status.connect(_on_update_status)
    if OS.get_cmdline_user_args().is_empty():
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
    if is_dedicated:
        print("ELDORIA DEDICATED SERVER READY %s" % ("WS TCP 7788" if is_websocket_host else "UDP 7777"))
        return
    own_id = multiplayer.get_unique_id()
    _spawn(own_id, Vector3(0, 1, 0))
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
    request_spawn.rpc_id(1)
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
    _remove_actor(id)
    if multiplayer.is_server():
        despawn_remote.rpc(id)

@rpc("authority", "call_remote", "reliable")
func despawn_remote(id: int) -> void:
    _remove_actor(id)

func _remove_actor(id: int) -> void:
    if players.has(id):
        players[id].queue_free()
        players.erase(id)
    emote_counts.erase(id)

func _clear_session() -> void:
    own_id = 0
    connected_peers.clear()
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
func request_spawn() -> void:
    if not multiplayer.is_server():
        return
    var id := multiplayer.get_remote_sender_id()
    for existing in players:
        spawn_remote.rpc_id(id, existing, players[existing].position)
    var pos := Vector3(float(players.size() * 3), 1, 0)
    _spawn(id, pos)
    spawn_remote.rpc(id, pos)

@rpc("authority", "call_remote", "reliable")
func spawn_remote(id: int, pos: Vector3) -> void:
    _spawn(id, pos)

func _spawn(id: int, pos: Vector3) -> void:
    if players.has(id):
        return
    var actor := MeshInstance3D.new()
    actor.name = "Player_%s" % id
    var mesh := CapsuleMesh.new()
    mesh.radius = .45
    mesh.height = 1.9
    actor.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("d6b674") if id == 1 else Color("729ce0")
    actor.material_override = mat
    actor.position = pos
    add_child(actor)
    players[id] = actor
    emote_counts[id] = 0

func _process(delta: float) -> void:
    if is_dedicated or own_id == 0 or not players.has(own_id):
        return
    if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
        return
    var axis: Vector2 = input_driver.get_move_vector()
    var delta_pos := Vector3(axis.x, 0, axis.y).rotated(Vector3.UP, input_driver.yaw) * MOVE_SPEED * delta
    players[own_id].position += delta_pos
    var focus: Vector3 = players[own_id].position + Vector3(0, 1.6, 0)
    var offset := Vector3(0, -sin(input_driver.pitch) * 13.0, cos(input_driver.pitch) * 13.0)
    var target: Vector3 = focus + offset.rotated(Vector3.UP, input_driver.yaw)
    camera.position = camera.position.lerp(target, minf(1.0, delta * 7.0))
    camera.look_at(focus, Vector3.UP)
    if multiplayer.is_server():
        sync_position.rpc(own_id, players[own_id].position)
    else:
        submit_position.rpc_id(1, players[own_id].position)

@rpc("any_peer", "unreliable")
func submit_position(pos: Vector3) -> void:
    if not multiplayer.is_server():
        return
    var id := multiplayer.get_remote_sender_id()
    if not players.has(id):
        return
    # Prototype-only sanity check; dedicated .NET server must validate time/speed.
    if players[id].position.distance_to(pos) > 4.0:
        return
    players[id].position = pos
    sync_position.rpc(id, pos)

@rpc("authority", "call_remote", "unreliable")
func sync_position(id: int, pos: Vector3) -> void:
    if id == own_id or not players.has(id):
        return
    players[id].position = pos

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
    var actor: MeshInstance3D = players[id]
    var mat: StandardMaterial3D = actor.material_override
    mat.albedo_color = Color("f7a45c") if emote_counts[id] % 2 != 0 else (Color("d6b674") if id == 1 else Color("729ce0"))
    _status("Player %d waved (%d)" % [id, emote_counts[id]])

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    if event.keycode == KEY_F11 and OS.get_name() != "Android":
        _toggle_fullscreen()
    elif event.keycode == KEY_E:
        _interact()

func _toggle_fullscreen() -> void:
    DISPLAY_SCRIPT.toggle_fullscreen()
