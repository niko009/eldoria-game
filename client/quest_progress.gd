extends RefCounted
# TASK-088 first playable quest. Only server-confirmed gather events advance it.
# Persistence stores bounded state, never client event IDs or reward amounts.
const ID := "first_supplies"
const GOALS := {"wood":3,"stone":2}
const REWARD_HERB := 2
const REWARD_XP := 5

static func initial() -> Dictionary:
    return {ID: {"status":"active","wood":0,"stone":0}}

static func valid(raw: Variant) -> bool:
    if not raw is Dictionary or raw.size() > 1:
        return false
    if raw.is_empty(): # Existing profiles, before quests were introduced.
        return true
    if not raw.has(ID) or not raw[ID] is Dictionary:
        return false
    var state: Dictionary = raw[ID]
    if state.size() != 3 or str(state.get("status","")) not in ["active","completed","claimed"]:
        return false
    for kind in GOALS:
        if not state.has(kind) or not (state[kind] is int or state[kind] is float):
            return false
        if int(state[kind]) < 0 or int(state[kind]) > int(GOALS[kind]) or float(state[kind]) != float(int(state[kind])):
            return false
    var done := int(state["wood"]) == GOALS["wood"] and int(state["stone"]) == GOALS["stone"]
    return state["status"] == "active" if not done else state["status"] in ["completed","claimed"]

static func normalize(raw: Variant) -> Dictionary:
    return raw.duplicate(true) if valid(raw) and not raw.is_empty() else initial()

static func gather(raw: Dictionary, kind: String, quantity: int) -> Dictionary:
    var quests := normalize(raw)
    if not GOALS.has(kind) or quantity <= 0 or quests[ID]["status"] != "active":
        return quests
    var current: Dictionary = quests[ID]
    current[kind] = mini(int(GOALS[kind]),int(current[kind])+quantity)
    if int(current["wood"]) == GOALS["wood"] and int(current["stone"]) == GOALS["stone"]:
        current["status"] = "completed"
    return quests

static func can_claim(raw: Dictionary, inventory: Dictionary, skills: Dictionary, avatar: int) -> bool:
    if not valid(raw) or raw.is_empty() or raw[ID]["status"] != "completed":
        return false
    var skill := reward_skill(avatar)
    return skill != "" and int(inventory.get("herb",0)) <= 1000000-REWARD_HERB and int(skills.get(skill,0)) <= 1000000-REWARD_XP

static func reward_skill(avatar: int) -> String:
    return "defense" if avatar == 0 else "archery" if avatar == 1 else "magic" if avatar == 2 else ""
