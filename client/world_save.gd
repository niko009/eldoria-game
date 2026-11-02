extends RefCounted
# Godot dedicated server's isolated, opt-in JSON persistence.
# It stores only hashed bearer identities, validated inventories and depleted
# resource counts. No plaintext player token, no client-side authority.
const SCHEMA := 1
const WORLD_SEED := 20261101
const ITEM_KINDS := ["wood","stone","herb"]
var save_path := ""
var last_error := ""
var profiles: Dictionary = {}
var depleted: Dictionary = {}

func configure(path: String) -> bool:
    save_path = path.strip_edges()
    if save_path.is_empty():
        return false
    var parent := save_path.get_base_dir()
    if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(parent)) != OK:
        last_error = "Cannot create save directory"
        return false
    return true

func load_snapshot(world: Node3D) -> bool:
    depleted.clear()
    profiles.clear()
    if save_path.is_empty():
        last_error = "No save path configured"
        return false
    if not FileAccess.file_exists(save_path):
        return true
    var file := FileAccess.open(save_path,FileAccess.READ)
    if file == null:
        last_error = "Cannot read snapshot file"
        return false
    if file.get_length() > 4*1024*1024:
        last_error = "Snapshot exceeds 4 MiB"
        return false
    var raw: String = file.get_as_text()
    var parser := JSON.new()
    if parser.parse(raw) != OK or not parser.data is Dictionary:
        last_error = "Malformed snapshot JSON"
        return false
    var doc: Dictionary = parser.data
    if int(doc.get("schema",0)) != SCHEMA or int(doc.get("world_seed",-1)) != WORLD_SEED:
        last_error = "Incompatible world schema or seed"
        return false
    var resource_data: Variant = doc.get("depleted",{})
    var player_data: Variant = doc.get("profiles",{})
    if not resource_data is Dictionary or not player_data is Dictionary:
        last_error = "Invalid snapshot data"
        return false
    for key in resource_data.keys():
        var id_text: String = str(key)
        if not id_text.is_valid_int():
            last_error = "Invalid resource identifier"
            return false
        var id := int(id_text)
        var entry: Dictionary = world.resource_by_id(id)
        if entry.is_empty():
            continue
        var amount := int(resource_data[key])
        if amount < 0 or amount > int(entry["amount"]):
            last_error = "Invalid resource quantity"
            return false
        if amount < int(entry["amount"]):
            depleted[id] = amount
    if player_data.size() > 5000:
        last_error = "Too many player profiles"
        return false
    for identity in player_data.keys():
        var hash_key: String = str(identity)
        if hash_key.length() != 64 or not hash_key.is_valid_hex_number():
            last_error = "Invalid player key"
            return false
        if not player_data[identity] is Dictionary:
            last_error = "Invalid profile data"
            return false
        var profile: Dictionary = player_data[identity]
        var original: Variant = profile.get("inventory",{})
        if not original is Dictionary:
            last_error = "Invalid inventory"
            return false
        var sanitized := {"wood":0,"stone":0,"herb":0}
        for kind in ITEM_KINDS:
            var v := int(original.get(kind,0))
            if v < 0 or v > 1000000:
                last_error = "Inventory out of range"
                return false
            sanitized[kind] = v
        var choice := int(profile.get("avatar",0))
        profiles[hash_key] = {"inventory":sanitized,"avatar":clampi(choice,0,2)}
    return true

func save_snapshot(remaining: Dictionary, world: Node3D) -> bool:
    if save_path.is_empty():
        return false
    var depleted_only := {}
    for key in remaining.keys():
        var id := int(key)
        var entry: Dictionary = world.resource_by_id(id)
        if entry.is_empty():
            continue
        var value := clampi(int(remaining[key]),0,int(entry["amount"]))
        if value < int(entry["amount"]):
            depleted_only[str(id)] = value
    var doc := {"schema":SCHEMA, "world_seed":WORLD_SEED, "depleted":depleted_only, "profiles":profiles}
    var temporary := save_path + ".tmp"
    var file := FileAccess.open(temporary,FileAccess.WRITE)
    if file == null:
        last_error = "Could not open temporary snapshot"
        return false
    file.store_string(JSON.stringify(doc,"  "))
    file.flush()
    file.close()
    var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(save_path))
    if err != OK:
        last_error = "Atomic snapshot replace failed: "+str(err)
        return false
    return true
