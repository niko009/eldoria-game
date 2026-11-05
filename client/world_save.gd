extends RefCounted
# Godot dedicated server's isolated, opt-in JSON persistence.
# It stores only hashed bearer identities, validated inventories and depleted
# resource counts. No plaintext player token, no client-side authority.
const SCHEMA := 1
const WORLD_SEED := 20261101
const ITEM_KINDS := ["wood","stone","herb","mana_herb","axe","bandage","repair_kit","spear","bow","shield","arrow","meat","hide","bone","leather_armor","grilled_meat","wooden_staff","mana_potion"]
var save_path := ""
var last_error := ""
var profiles: Dictionary = {}
var depleted: Dictionary = {}
var buildings: Dictionary = {}

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
    buildings.clear()
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
    var build_data: Variant = doc.get("buildings",{})
    if not resource_data is Dictionary or not player_data is Dictionary or not build_data is Dictionary or build_data.size() > 300:
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
    for key in build_data.keys():
        if not str(key).is_valid_int() or int(key) < 1 or int(key) > 100000:
            last_error = "Invalid building id"
            return false
        var rec: Variant = build_data[key]
        if not rec is Dictionary or not str(rec.get("kind","")) in ["tent","campfire"]:
            last_error = "Invalid building data"
            return false
        var x := float(rec.get("x",INF))
        var z := float(rec.get("z",INF))
        if not is_finite(x) or not is_finite(z) or absf(x) > 75 or absf(z) > 75:
            last_error = "Invalid building position"
            return false
        buildings[int(key)] = {"kind":rec["kind"],"x":x,"z":z}
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
        var sanitized := {"wood":0,"stone":0,"herb":0,"mana_herb":0,"axe":0,"bandage":0,
            "repair_kit":0,"spear":0,"bow":0,"shield":0,"arrow":0,
            "meat":0,"hide":0,"bone":0,"leather_armor":0,"grilled_meat":0,"wooden_staff":0,"mana_potion":0}
        for kind in ITEM_KINDS:
            var v := int(original.get(kind,0))
            var limit := 1 if kind in ["axe","spear","bow","shield","leather_armor","wooden_staff"] else 40 if kind == "arrow" else 20 if kind in ["bandage","repair_kit","grilled_meat","mana_potion"] else 1000000
            if v < 0 or v > limit:
                last_error = "Inventory out of range"
                return false
            sanitized[kind] = v
        var skills := {"archery":0,"spear":0,"defense":0,"magic":0}
        var source_skills: Variant = profile.get("skills",{})
        if source_skills != null and not source_skills is Dictionary:
            last_error = "Invalid skills"
            return false
        if source_skills is Dictionary:
            for kind in skills:
                var points := int(source_skills.get(kind,0))
                if points < 0 or points > 1000000:
                    last_error = "Skills out of range"
                    return false
                skills[kind] = points
        var choice := int(profile.get("avatar",0))
        var raw_equipment: Variant = profile.get("equipment",{})
        if not raw_equipment is Dictionary:
            last_error = "Invalid equipment structure"
            return false
        var equipment: Dictionary = raw_equipment
        if not _valid_equipment(equipment,sanitized,choice):
            last_error = "Invalid equipment"
            return false
        profiles[hash_key] = {"inventory":sanitized,"avatar":clampi(choice,0,2),"skills":skills,"equipment":_normalize_equipment(equipment)}
    return true

static func _normalize_equipment(value: Dictionary) -> Dictionary:
    return {"main_hand":str(value.get("main_hand","unarmed")),"off_hand":str(value.get("off_hand","unarmed")),"chest":str(value.get("chest","unarmed"))}

static func _valid_equipment(value: Dictionary,inventory: Dictionary,avatar: int) -> bool:
    var slots := _normalize_equipment(value)
    var main: String = slots["main_hand"]
    var off: String = slots["off_hand"]
    var chest: String = slots["chest"]
    return main in ["unarmed","staff","wooden_staff","spear","bow"] and off in ["unarmed","shield"] and chest in ["unarmed","leather_armor"] and (main not in ["staff","wooden_staff"] or avatar == 2) and (main not in ["spear","bow","wooden_staff"] or int(inventory.get(main,0)) > 0) and (off != "shield" or int(inventory.get("shield",0)) > 0) and (chest != "leather_armor" or int(inventory.get("leather_armor",0)) > 0) and (main not in ["spear","bow"] or off != "shield")

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
    var doc := {"schema":SCHEMA, "world_seed":WORLD_SEED, "depleted":depleted_only, "profiles":profiles,"buildings":buildings}
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
