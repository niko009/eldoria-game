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

# The token is a bearer credential for the prototype, never sent to other peers.
# It is random (256 bits) and only its SHA-256 digest is kept on the server.
static func valid_token(token: String) -> bool:
    return token.length() == 64 and token.is_valid_hex_number()

static func read_token() -> String:
    var config := ConfigFile.new()
    config.load(PROFILE_PATH)
    var old: String = str(config.get_value("player","identity",""))
    if valid_token(old):
        return old
    var token := Crypto.new().generate_random_bytes(32).hex_encode()
    if not valid_token(token):
        return ""
    config.set_value("player","identity",token)
    if config.save(PROFILE_PATH) != OK:
        return ""
    return token
