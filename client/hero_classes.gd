extends RefCounted
## Class rules live in one place; the server is authoritative for effects.
const KNIGHT := 0
const ROGUE := 1
const MAGE := 2
const KNIGHT_DAMAGE_TAKEN := 0.90
const ROGUE_SPEED_MULTIPLIER := 1.10
const ROGUE_DASH_DISTANCE := 2.5
const ROGUE_DASH_COOLDOWN_MS := 9000
const MAGE_MANA_MAX := 100
const MAGE_MANA_COST := 40
const MAGE_MANA_REGEN_PER_SEC := 8.0
const MAGE_HEAL_HP := 35
const MAGE_HEAL_RADIUS := 6.0
const MAGE_HEAL_COOLDOWN_MS := 12000

static func ability_label(hero: int) -> String:
    match hero:
        KNIGHT:
            return "ЗОВ"
        ROGUE:
            return "РЫВОК"
        MAGE:
            return "ЛЕЧИТЬ"
    return "УМЕНИЕ"

static func class_description(hero: int) -> String:
    match hero:
        KNIGHT:
            return "Рыцарь · снижает входящий урон на 10%. Зов отвлекает волков со щитом."
        ROGUE:
            return "Разбойник · скорость +10%. Рывок до 2,5 м, откат 9 с."
        MAGE:
            return "Маг · восстанавливает ману. Лечит союзника или себя на 35 HP."
    return ""