extends RefCounted
# Private Godot-headless -> loopback-only .NET Persistence API -> PostgreSQL.
# All HTTP is on the dedicated server; Android/Windows clients never reach SQL.
const WORLD_SEED := 20261101
const API_ROUTE := "/v1/world/20261101"
const TIMEOUT_MS := 8000
const MAX_BODY := 4*1024*1024
var port := 0
var api_key := ""
var revision := 0
var profiles: Dictionary = {}
var depleted: Dictionary = {}
var buildings: Dictionary = {}
var last_error := ""
var _connected := false

func configure(address: String, key: String) -> bool:
    if not address.begins_with("http://127.0.0.1:"):
        last_error = "Only 127.0.0.1 HTTP is permitted for internal persistence"
        return false
    var port_text := address.trim_prefix("http://127.0.0.1:").trim_suffix("/")
    if not port_text.is_valid_int() or key.length() < 24:
        last_error = "Missing port or server-only API key"
        return false
    port = int(port_text)
    api_key = key
    if port < 1 or port > 65535:
        last_error = "Invalid loopback port"
        return false
    _connected = true
    return true

func _request(method: HTTPClient.Method, body: String = "") -> Dictionary:
    if not _connected:
        last_error = "Persistence API was not configured"
        return {}
    var http := HTTPClient.new()
    var err := http.connect_to_host("127.0.0.1",port)
    if err != OK:
        last_error = "Could not connect to internal persistence endpoint"
        return {}
    var deadline := Time.get_ticks_msec()+TIMEOUT_MS
    while http.get_status() in [HTTPClient.STATUS_CONNECTING,HTTPClient.STATUS_RESOLVING]:
        err = http.poll()
        if err != OK or Time.get_ticks_msec() >= deadline:
            http.close()
            last_error = "Persistence API connection timed out"
            return {}
        OS.delay_msec(2)
    if http.get_status() != HTTPClient.STATUS_CONNECTED:
        last_error = "Persistence API not reachable"
        http.close()
        return {}
    var headers := PackedStringArray([
        "X-Eldoria-Server-Key: " + api_key,
        "Accept: application/json",
        "Content-Type: application/json"])
    err = http.request(method, API_ROUTE, headers, body)
    if err != OK:
        last_error = "Persistence API request failed"
        http.close()
        return {}
    while http.get_status() in [HTTPClient.STATUS_CONNECTED,HTTPClient.STATUS_REQUESTING]:
        if http.poll() != OK or Time.get_ticks_msec() >= deadline:
            http.close()
            last_error = "Persistence API response timeout"
            return {}
        OS.delay_msec(1)
    var status := http.get_response_code()
    var received := PackedByteArray()
    while http.get_status() == HTTPClient.STATUS_BODY:
        if http.poll() != OK or Time.get_ticks_msec() >= deadline:
            http.close()
            last_error = "Persistence API body timeout"
            return {}
        var part := http.read_response_body_chunk()
        if not part.is_empty():
            received.append_array(part)
        if received.size() > MAX_BODY:
            http.close()
            last_error = "Persistence API response exceeds 4 MiB"
            return {}
        if part.is_empty():
            OS.delay_msec(1)
    http.close()
    if status != 200:
        last_error = "Persistence API status %d" % status
        return {}
    var parser := JSON.new()
    if parser.parse(received.get_string_from_utf8()) != OK or not parser.data is Dictionary:
        last_error = "Malformed persistence API response"
        return {}
    return parser.data

func load_snapshot(world: Node3D) -> bool:
    profiles.clear()
    depleted.clear()
    buildings.clear()
    var snapshot := {}
    for attempt in 3:
        snapshot = _request(HTTPClient.METHOD_GET)
        if not snapshot.is_empty():
            break
        # A temporarily overloaded local API must not cause a silent reset.
        # Only transient network errors are retryable; malformed world data
        # is still rejected below without attempting recovery.
        if not _is_transient_error():
            break
        OS.delay_msec(200)
    if snapshot.is_empty():
        return false
    if int(snapshot.get("schema",-1)) != 1 or int(snapshot.get("world_seed",-1)) != WORLD_SEED:
        last_error = "World schema/seed mismatch"
        return false
    revision = int(snapshot.get("revision",-1))
    if revision < 0 or not snapshot.get("depleted") is Dictionary or not snapshot.get("profiles") is Dictionary:
        last_error = "Invalid PostgreSQL snapshot"
        return false
    for id_text in snapshot["depleted"].keys():
        if not str(id_text).is_valid_int():
            last_error = "Invalid PostgreSQL resource ID"
            return false
        var id := int(id_text)
        var entry: Dictionary = world.resource_by_id(id)
        if entry.is_empty():
            last_error = "PostgreSQL world resource does not exist"
            return false
        var value := int(snapshot["depleted"][id_text])
        if value < 0 or value > int(entry["amount"]):
            last_error = "Invalid PostgreSQL resource quantity"
            return false
        depleted[id] = value
    for identity in snapshot["profiles"].keys():
        var hash_key := String(identity)
        if hash_key.length()!=64 or not hash_key.is_valid_hex_number():
            last_error = "Invalid hashed identity"
            return false
        var profile: Variant = snapshot["profiles"][identity]
        if not profile is Dictionary or not profile.get("inventory") is Dictionary:
            last_error = "Malformed player data"
            return false
        var inventory := {"wood":0,"stone":0,"herb":0,"axe":0,"bandage":0,
            "repair_kit":0,"spear":0,"bow":0,"shield":0,"arrow":0,
            "meat":0,"hide":0,"bone":0,"leather_armor":0,"grilled_meat":0}
        for kind in inventory.keys():
            var amount := int(profile["inventory"].get(kind,0))
            var limit := 1 if kind in ["axe","spear","bow","shield","leather_armor"] else 40 if kind == "arrow" else 20 if kind in ["bandage","repair_kit","grilled_meat"] else 1000000
            if amount < 0 or amount > limit:
                last_error = "Invalid player inventory"
                return false
            inventory[kind] = amount
        var skills := {"archery":0,"spear":0,"defense":0}
        var raw_skills: Variant = profile.get("skills",{})
        if raw_skills != null and not raw_skills is Dictionary:
            last_error = "Invalid player skills"
            return false
        if raw_skills is Dictionary:
            for kind in skills:
                var amount := int(raw_skills.get(kind,0))
                if amount < 0 or amount > 1000000:
                    last_error = "Invalid player skill points"
                    return false
                skills[kind] = amount
        var avatar := int(profile.get("avatar",-1))
        if avatar < 0 or avatar > 2:
            last_error = "Invalid player avatar"
            return false
        profiles[hash_key] = {"avatar":avatar,"inventory":inventory,"skills":skills}
    var build_data: Variant = snapshot.get("buildings",{})
    if not build_data is Dictionary or build_data.size() > 300:
        last_error = "Invalid building snapshot"
        return false
    for id in build_data.keys():
        if not str(id).is_valid_int() or int(id) < 1:
            last_error = "Invalid building ID"
            return false
        var record: Variant = build_data[id]
        if not record is Dictionary or not str(record.get("kind","")) in ["tent","campfire"]:
            last_error = "Invalid building entry"
            return false
        var x := float(record.get("x",INF))
        var z := float(record.get("z",INF))
        if not is_finite(x) or not is_finite(z) or absf(x)>75 or absf(z)>75:
            last_error = "Invalid building coordinates"
            return false
        buildings[int(id)] = {"kind":record["kind"],"x":x,"z":z}
    return true

func save_snapshot(remaining: Dictionary, world: Node3D) -> bool:
    var depleted_only := {}
    for key in remaining.keys():
        var id := int(key)
        var entry: Dictionary = world.resource_by_id(id)
        if entry.is_empty():
            continue
        var amount := int(remaining[key])
        if amount < 0 or amount > int(entry["amount"]):
            last_error = "Invalid resource amount to persist"
            return false
        if amount < int(entry["amount"]):
            depleted_only[str(id)] = amount
    var snapshot := {
        "schema":1, "world_seed":WORLD_SEED,"revision":revision,
        "profiles":profiles,"depleted":depleted_only,"buildings":buildings}
    var response := _request(HTTPClient.METHOD_PUT,JSON.stringify(snapshot))
    if response.is_empty() or not response.has("revision"):
        # A timed-out PUT may have already committed. The next PUT then gets
        # revision 409 forever unless the client reconciles the lost ACK.
        # NEVER trust 409 alone: require exactly one next revision and the
        # database contents to match the exact state we intended to write.
        if not _is_transient_error() and last_error != "Persistence API status 409":
            return false
        var original_error := last_error
        for attempt in 3:
            var live := _request(HTTPClient.METHOD_GET)
            if not live.is_empty():
                if int(live.get("revision",-1)) == revision+1 and _snapshot_matches(live,snapshot):
                    revision += 1
                    last_error = ""
                    return true
                last_error = "Persistence revision conflict; refusing unsafe overwrite"
                return false
            OS.delay_msec(150)
        last_error = "Cannot verify ambiguous save after: " + original_error
        return false
    var next_revision := int(response["revision"])
    if next_revision != revision + 1:
        last_error = "Non-monotonic PostgreSQL revision"
        return false
    revision = next_revision
    return true

func _is_transient_error() -> bool:
    return last_error.contains("timeout") or last_error.contains("timed out") or last_error == "Persistence API not reachable" or last_error in ["Persistence API status 429","Persistence API status 502","Persistence API status 503","Persistence API status 504"]

func _snapshot_matches(live: Dictionary, expected: Dictionary) -> bool:
    if int(live.get("world_seed",-1)) != WORLD_SEED or int(live.get("schema",-1)) != 1:
        return false
    var remote_resources: Variant = live.get("depleted",{})
    var local_resources: Variant = expected.get("depleted",{})
    if not remote_resources is Dictionary or remote_resources.size() != local_resources.size():
        return false
    for key in local_resources:
        if not remote_resources.has(str(key)) or int(remote_resources[str(key)]) != int(local_resources[key]):
            return false
    var remote_profiles: Variant = live.get("profiles",{})
    var local_profiles: Variant = expected.get("profiles",{})
    if not remote_profiles is Dictionary or remote_profiles.size() != local_profiles.size():
        return false
    for identity in local_profiles:
        if not remote_profiles.has(identity):
            return false
        var remote: Dictionary = remote_profiles[identity]
        var wanted: Dictionary = local_profiles[identity]
        if int(remote.get("avatar",-1)) != int(wanted.get("avatar",-1)):
            return false
        for item in ["wood","stone","herb","axe","bandage","repair_kit","spear","bow","shield","arrow","meat","hide","bone","leather_armor","grilled_meat"]:
            if int(remote.get("inventory",{}).get(item,-1)) != int(wanted.get("inventory",{}).get(item,0)):
                return false
        for skill in ["archery","spear","defense"]:
            if int(remote.get("skills",{}).get(skill,-1)) != int(wanted.get("skills",{}).get(skill,0)):
                return false
    var remote_buildings: Variant = live.get("buildings",{})
    var local_buildings: Variant = expected.get("buildings",{})
    if not remote_buildings is Dictionary or remote_buildings.size() != local_buildings.size():
        return false
    for key in local_buildings:
        if not remote_buildings.has(str(key)):
            return false
        var actual: Dictionary = remote_buildings[str(key)]
        var wanted: Dictionary = local_buildings[key]
        if str(actual.get("kind","")) != str(wanted.get("kind","")) or absf(float(actual.get("x",INF))-float(wanted.get("x",INF))) > 0.0001 or absf(float(actual.get("z",INF))-float(wanted.get("z",INF))) > 0.0001:
            return false
    return true
