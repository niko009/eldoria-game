extends VBoxContainer
## Read-only visual presentation of server-synchronized skill XP.
const Style = preload("res://ui/ui_style.gd")
const Progression = preload("res://combat_progression.gd")

const NAMES := {
    "archery": "СТРЕЛЬБА ИЗ ЛУКА",
    "spear": "ВЛАДЕНИЕ КОПЬЁМ",
    "defense": "ЗАЩИТА ЩИТОМ",
    "magic": "МАГИЯ"
}
var skills: Dictionary = {"archery": 0, "spear": 0, "defense": 0, "magic": 0}

func _ready() -> void:
    add_theme_constant_override("separation", 13)
    refresh()

func set_skills(values: Dictionary) -> void:
    for skill in NAMES:
        skills[skill] = clampi(int(values.get(skill,0)),0,Progression.MAX_XP)
    if is_inside_tree():
        refresh()

func refresh() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    var intro := Style.label("Постоянные навыки. Опыт начисляет только сервер.", 13, Style.MUTED)
    intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_child(intro)
    for skill in ["archery","spear","defense","magic"]:
        var xp: int = int(skills[skill])
        var level := Progression.level_for_xp(xp)
        var next_level := Progression.xp_required_for_level(level+1)
        var level_start := Progression.xp_required_for_level(level)
        var card := PanelContainer.new()
        card.name = "Skill_%s" % skill
        card.add_theme_stylebox_override("panel",Style.panel(Color("1e302f",0.93),Color("719a7c",0.55),12))
        add_child(card)
        var lines := VBoxContainer.new()
        lines.name = "Details"
        lines.add_theme_constant_override("separation",6)
        card.add_child(lines)
        var name := Style.label("%s · УРОВЕНЬ %d" % [NAMES[skill],level],16,Style.GOLD)
        name.name = "Level"
        lines.add_child(name)
        var bonus := Style.label(Progression.bonus_description(skill,xp),14,Color("b3e5b2"))
        bonus.name = "Bonus"
        lines.add_child(bonus)
        var gauge := ProgressBar.new()
        gauge.name = "XpProgress"
        gauge.show_percentage = false
        gauge.custom_minimum_size = Vector2(160,12)
        gauge.max_value = maxf(1.0,float(next_level-level_start))
        gauge.value = float(xp-level_start)
        lines.add_child(gauge)
        var status := "XP %d/%d · осталось %d" % [xp,next_level,maxi(0,next_level-xp)]
        if xp >= Progression.MAX_XP:
            status = "Достигнут предел опыта"
        lines.add_child(Style.label(status,12,Style.MUTED))
    var note := Style.label("Боевой бонус ограничен пятым уровнем.\nТренировка: манекены, охота и защита лагеря.",13,Style.MUTED)
    note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    add_child(note)