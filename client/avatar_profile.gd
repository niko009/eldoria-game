extends RefCounted
# Client-side avatar preference; the server independently validates the value.
const NAMES := ["Knight", "Rogue_Hooded", "Mage"]
const LABELS := ["Knight / Рыцарь", "Rogue / Разбойник", "Mage / Маг"]
const PROFILE_PATH := "user://eldoria-profile.cfg"

static func valid(value: int) -> bool:
    return value >= 0 and value < NAMES.size()

static func normalized(value: int) -> int:
    return value if valid(value) else 0

static func read_choice() -> int:
    var config := ConfigFile.new()
    if config.load(PROFILE_PATH) != OK:
        return 0
    return normalized(int(config.get_value("player", "avatar", 0)))

static func save_choice(value: int) -> int:
    if not valid(value):
        return ERR_INVALID_PARAMETER
    var config := ConfigFile.new()
    config.load(PROFILE_PATH)
    config.set_value("player", "avatar", value)
    return config.save(PROFILE_PATH)
