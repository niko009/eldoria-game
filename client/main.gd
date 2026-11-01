extends Node3D

const PORT := 7777
var peer := ENetMultiplayerPeer.new()
var players := {}
var own_id := 0
var camera: Camera3D
var info: Label
var ip_input: LineEdit
var move_input := Vector2.ZERO
var move_speed := 6.0

func _ready() -> void:
    _world()
    _ui()
    multiplayer.peer_connected.connect(_on_join)
    multiplayer.peer_disconnected.connect(_on_leave)
    multiplayer.connected_to_server.connect(_connected)
    multiplayer.connection_failed.connect(_connection_failed)
    multiplayer.server_disconnected.connect(_server_disconnected)

func _world() -> void:
    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-55, 35, 0)
    add_child(light)
    var env := WorldEnvironment.new()
    env.environment = Environment.new()
    env.environment.background_mode = Environment.BG_COLOR
    env.environment.background_color = Color("8cb5c7")
    add_child(env)
    var ground := MeshInstance3D.new()
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(160,160)
    ground.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color("527e50")
    ground.material_override = mat
    add_child(ground)
    for i in range(35):
        var tree := MeshInstance3D.new()
        var trunk := CylinderMesh.new()
        trunk.top_radius = .22
        trunk.bottom_radius = .32
        trunk.height = 3
        tree.mesh = trunk
        tree.position = Vector3(sin(i*8.1)*35,1.5,cos(i*5.3)*35)
        var tm := StandardMaterial3D.new()
        tm.albedo_color = Color("76583b")
        tree.material_override = tm
        add_child(tree)
        var leaves := MeshInstance3D.new()
        leaves.mesh = SphereMesh.new()
        leaves.scale = Vector3(1.7,2.3,1.7)
        leaves.position = tree.position + Vector3(0,2.7,0)
        var lm := StandardMaterial3D.new()
        lm.albedo_color = Color("285c39")
        leaves.material_override = lm
        add_child(leaves)
    camera = Camera3D.new()
    camera.position = Vector3(0,16,22)
    camera.rotation_degrees.x = -35
    camera.current = true
    add_child(camera)

func _ui() -> void:
    var ui := CanvasLayer.new()
    add_child(ui)
    var panel := VBoxContainer.new()
    panel.position = Vector2(24,24)
    ui.add_child(panel)
    var title := Label.new()
    title.text = "ELDORIA  /  ONLINE PROTOTYPE"
    panel.add_child(title)
    ip_input = LineEdit.new()
    ip_input.text = "127.0.0.1"
    ip_input.custom_minimum_size.x = 240
    panel.add_child(ip_input)
    var host := Button.new()
    host.text = "Host world"
    host.pressed.connect(_host)
    panel.add_child(host)
    var join := Button.new()
    join.text = "Join world"
    join.pressed.connect(_join)
    panel.add_child(join)
    info = Label.new()
    info.text = "Host or join. WASD to move."
    panel.add_child(info)
    var mobile := Control.new()
    mobile.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    mobile.offset_left = 24
    mobile.offset_top = -190
    mobile.offset_right = 230
    mobile.offset_bottom = -16
    ui.add_child(mobile)
    for entry in [["▲",Vector2(65,0),Vector2(0,-1)],["▼",Vector2(65,112),Vector2(0,1)],["◀",Vector2(0,56),Vector2(-1,0)],["▶",Vector2(130,56),Vector2(1,0)]]:
        var button := Button.new()
        button.text = entry[0]
        button.position = entry[1]
        button.custom_minimum_size = Vector2(58,52)
        button.button_down.connect(func(): move_input += entry[2])
        button.button_up.connect(func(): move_input -= entry[2])
        mobile.add_child(button)
    var disconnect := Button.new()
    disconnect.text = "Disconnect"
    disconnect.pressed.connect(_disconnect)
    panel.add_child(disconnect)

func _host() -> void:
    _clear_session()
    peer = ENetMultiplayerPeer.new()
    if peer.create_server(PORT,10) != OK:
        info.text = "Cannot host on UDP 7777"
        return
    multiplayer.multiplayer_peer = peer
    own_id = multiplayer.get_unique_id()
    _spawn(own_id,Vector3(0,1,0))
    info.text = "Hosting UDP 7777, ID %s" % own_id

func _join() -> void:
    _clear_session()
    peer = ENetMultiplayerPeer.new()
    if peer.create_client(ip_input.text.strip_edges(),PORT) != OK:
        info.text = "Cannot connect"
        return
    multiplayer.multiplayer_peer = peer
    info.text = "Connecting..."

func _connected() -> void:
    own_id = multiplayer.get_unique_id()
    request_spawn.rpc_id(1)
    info.text = "Connected, ID %s" % own_id

func _on_join(id: int) -> void:
    if multiplayer.is_server():
        info.text = "Player %s connected" % id

func _on_leave(id: int) -> void:
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

func _clear_session() -> void:
    own_id = 0
    move_input = Vector2.ZERO
    multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
    peer.close()
    for id in players.keys():
        _remove_actor(id)

func _disconnect() -> void:
    _clear_session()
    info.text = "Disconnected. Host or join to play."

func _connection_failed() -> void:
    _clear_session()
    info.text = "Connection failed"

func _server_disconnected() -> void:
    _clear_session()
    info.text = "Server disconnected"

@rpc("any_peer","reliable")
func request_spawn() -> void:
    if not multiplayer.is_server(): return
    var id := multiplayer.get_remote_sender_id()
    for existing in players:
        spawn_remote.rpc_id(id,existing,players[existing].position)
    var pos := Vector3(float(players.size()*3),1,0)
    _spawn(id,pos)
    spawn_remote.rpc(id,pos)

@rpc("authority","call_remote","reliable")
func spawn_remote(id: int, pos: Vector3) -> void:
    _spawn(id,pos)

func _spawn(id: int,pos: Vector3) -> void:
    if players.has(id): return
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

func _process(delta: float) -> void:
    if own_id == 0 or not players.has(own_id): return
    if peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED: return
    var axis := Input.get_vector("move_left","move_right","move_forward","move_back") + move_input
    axis = axis.limit_length()
    var delta_pos := Vector3(axis.x,0,axis.y)*move_speed*delta
    players[own_id].position += delta_pos
    var target: Vector3 = players[own_id].position + Vector3(0,12,19)
    camera.position = camera.position.lerp(target,min(1,delta*5))
    if multiplayer.is_server():
        sync_position.rpc(own_id,players[own_id].position)
    else:
        submit_position.rpc_id(1,players[own_id].position)

@rpc("any_peer","unreliable")
func submit_position(pos: Vector3) -> void:
    if not multiplayer.is_server(): return
    var id := multiplayer.get_remote_sender_id()
    if not players.has(id): return
    if players[id].position.distance_to(pos) > 4.0: return
    players[id].position = pos
    sync_position.rpc(id,pos)

@rpc("authority","call_remote","unreliable")
func sync_position(id: int,pos: Vector3) -> void:
    if id == own_id or not players.has(id): return
    players[id].position = pos
