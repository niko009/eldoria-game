extends RefCounted
## Shared progression math: client displays levels, server calculates effects.
## The server never trusts a client-supplied level, XP or damage value.
const MAX_XP := 1000000
const MAX_BONUS_TIERS := 4
const XP_SQUARE_FACTOR := 25
const BASE_BOW_DAMAGE := 20
const BASE_SPEAR_DAMAGE := 30
const DAMAGE_PER_TIER := 2
const SHIELD_BASE_FACTOR := 0.60
const SHIELD_FACTOR_PER_TIER := 0.05

static func level_for_xp(xp: int) -> int:
    return 1 + floori(sqrt(float(clampi(xp, 0, MAX_XP)) / XP_SQUARE_FACTOR))

static func xp_required_for_level(level: int) -> int:
    if level <= 1:
        return 0
    return mini(MAX_XP, (level - 1) * (level - 1) * XP_SQUARE_FACTOR)

static func bonus_tiers(xp: int) -> int:
    return mini(MAX_BONUS_TIERS, level_for_xp(xp) - 1)

static func weapon_damage(weapon: String, xp: int) -> int:
    if weapon not in ["bow", "spear"]:
        return 0
    var base := BASE_BOW_DAMAGE if weapon == "bow" else BASE_SPEAR_DAMAGE
    return base + bonus_tiers(xp) * DAMAGE_PER_TIER

static func shield_damage_taken(raw_damage: int, xp: int) -> int:
    if raw_damage <= 0:
        return 0
    var fraction := SHIELD_BASE_FACTOR - float(bonus_tiers(xp)) * SHIELD_FACTOR_PER_TIER
    return maxi(1, ceili(float(raw_damage) * fraction))

static func bonus_description(skill: String, xp: int) -> String:
    var tiers := bonus_tiers(xp)
    match skill:
        "archery", "spear":
            return "+%d к урону" % (tiers * DAMAGE_PER_TIER)
        "defense":
            return "Поглощение %d%%" % (40 + tiers * 5)
        "magic":
            return "+%d к урону заклинаний" % (tiers * 2)
    return ""