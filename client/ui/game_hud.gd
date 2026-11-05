extends Control
class_name EldoriaGameHud

signal open_inventory
signal open_building
signal open_crafting
signal item_selected(item_id: String)
signal action_requested(action_id: String)
signal open_settings
signal open_skills
signal zoom_requested(step: float)

const Style = preload("res://ui/ui_style.gd")
const State = preload("res://ui/mock_game_ui_state.gd")
const Glyph = preload("res://ui/hud_glyph.gd")
const Progression = preload("res://combat_progression.gd")
const HotbarScene = preload("res://ui/Hotbar.tscn")

const CREAM := Color("f5eedc")
const GOLD := Color("e5bd77")
const INK := Color("151e23")
const SAGE := Color("8fbd9c")

var state: MockGameUiState
var show_touch_controls := true
var preview_mode := true

var status_panel: PanelContainer
var status_detail: Label
var health_detail: Label
var health_bar: ProgressBar
var xp_bar: ProgressBar
var xp_label: Label
var avatar_name: Label
var warning_detail: Label
var resources_panel: HBoxContainer
var progress_panel: HBoxContainer
var resource_counts: Dictionary = {}
var practice_label: Label
var hunt_progress := 0
var alpha_wolf_hp := 0
var mana_label: Label
var _mana_needs_refill := false
var last_practice_points := 0
var last_skills := {"archery":0,"spear":0,"defense":0}
var hotbar: EldoriaHotbar
var touch_layer: Control
var joystick: Control
var action_buttons: Control
var top_actions: HBoxContainer
var selected_tool_hint: Label
var combat_mode := "unarmed"
var raid_banner: Label
var heal_button: Button
var repair_button: Button
var quick_consumables: HBoxContainer
var quick_buttons: Dictionary = {}
var zoom_controls: HBoxContainer
var camp_health := -1
var action_controls: Dictionary = {}
var top_controls: Dictionary = {}
var craft_badge: PanelContainer
var craft_badge_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout)
	_create_status()
	_create_resources()
	_create_menu()
	_create_hotbar()
	_create_touch()
	_create_warning()
	_create_raid_ui()
	_create_quick_consumables()
	_create_zoom_controls()
	if state != null:
		state.changed.connect(refresh)
	refresh()

func _create_status() -> void:
	status_panel = PanelContainer.new()
	status_panel.name = "PlayerStatus"
	status_panel.add_theme_stylebox_override("panel", _card(Color("142329", 0.84), Color("d6bd89", 0.39), 13, 6))
	add_child(status_panel)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 9)
	status_panel.add_child(body)
	var crest := PanelContainer.new()
	crest.custom_minimum_size = Vector2(34, 34)
	crest.add_theme_stylebox_override("panel", _card(Color("9c8358", 0.30), Color("e5bd77", 0.30), 13, 4))
	body.add_child(crest)
	var symbol := Style.label("✦", 23, GOLD)
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crest.add_child(symbol)
	var stats := VBoxContainer.new()
	stats.add_theme_constant_override("separation", 3)
	stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(stats)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	stats.add_child(title_row)
	avatar_name = Style.label("РЫЦАРЬ", 14, CREAM)
	avatar_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(avatar_name)
	status_detail = Style.label("●", 12, SAGE)
	title_row.add_child(status_detail)
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 6)
	stats.add_child(hp_row)
	health_bar = ProgressBar.new()
	health_bar.name = "HealthGauge"
	health_bar.custom_minimum_size = Vector2(115, 9)
	health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_bar.show_percentage = false
	var track := _card(Color("060e13", 0.93), Color.TRANSPARENT, 4, 0)
	var fill := _card(Color("b2d18f"), Color.TRANSPARENT, 4, 0)
	health_bar.add_theme_stylebox_override("background", track)
	health_bar.add_theme_stylebox_override("fill", fill)
	hp_row.add_child(health_bar)
	health_detail = Style.label("—", 12, CREAM)
	hp_row.add_child(health_detail)
	var xp_row := HBoxContainer.new()
	xp_row.name = "ExperienceRow"
	stats.add_child(xp_row)
	xp_label = Style.label("Навык · ур. 1",11,GOLD)
	xp_row.add_child(xp_label)
	xp_bar = ProgressBar.new()
	xp_bar.name = "ExperienceGauge"
	xp_bar.custom_minimum_size = Vector2(80,6)
	xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_bar.show_percentage = false
	xp_bar.max_value = 1
	xp_row.add_child(xp_bar)

func _create_resources() -> void:
	resources_panel = HBoxContainer.new()
	resources_panel.name = "ResourceCounters"
	resources_panel.add_theme_constant_override("separation", 7)
	add_child(resources_panel)
	for kind in ["wood", "stone", "herb"]:
		var chip := PanelContainer.new()
		chip.name = "Resource_%s" % kind
		chip.add_theme_stylebox_override("panel", _card(Color("142329", 0.77), Color("cfbd96", 0.21), 12, 5))
		resources_panel.add_child(chip)
		var content := HBoxContainer.new()
		content.add_theme_constant_override("separation", 3)
		chip.add_child(content)
		var mark: Control = Glyph.new()
		mark.name = "Glyph"
		mark.custom_minimum_size = Vector2(23, 23)
		mark.setup(kind, {"wood": Color("daab70"), "stone": Color("b7c8c8"), "herb": Color("97bf90")}[kind])
		content.add_child(mark)
		var quantity := Style.label("0", 15, CREAM)
		quantity.name = "Count"
		quantity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		content.add_child(quantity)
		chip.tooltip_text = State.ITEMS[kind]["name"]
		resource_counts[kind] = quantity
	progress_panel = HBoxContainer.new()
	progress_panel.name = "ProgressIndicators"
	progress_panel.add_theme_constant_override("separation", 12)
	add_child(progress_panel)
	practice_label = Style.label("Тренировка: 0", 13, Color("c8edb5"))
	practice_label.name = "PracticePoints"
	practice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	progress_panel.add_child(practice_label)
	mana_label = Style.label("Мана 100/100",13,Color("a5c7f3"))
	mana_label.name = "HeroMana"
	mana_label.visible = false
	progress_panel.add_child(mana_label)

func set_mana(value: int, mage: bool) -> void:
	_mana_needs_refill = value < 100
	if mana_label != null:
		mana_label.visible = mage
		mana_label.text = "Мана %d/100" % clampi(value,0,100)
	_refresh_quick_consumables()


func set_hunt_progress(progress: int) -> void:
	hunt_progress = clampi(progress,0,5)
	_refresh_skills_label()

func set_alpha_wolf_health(hp: int, alive: bool) -> void:
	alpha_wolf_hp = clampi(hp,0,180) if alive else 0
	_refresh_skills_label()

func set_practice_points(points: int) -> void:
	last_practice_points = points
	_refresh_skills_label()

func set_skills(skills: Dictionary) -> void:
	last_skills = skills.duplicate(true)
	_refresh_skills_label()

func _refresh_skills_label() -> void:
	if practice_label == null:
		return
	var a := Progression.level_for_xp(int(last_skills.get("archery",0)))
	var s := Progression.level_for_xp(int(last_skills.get("spear",0)))
	var d := Progression.level_for_xp(int(last_skills.get("defense",0)))
	var best_skill := "archery"
	for skill in ["spear","defense"]:
		if int(last_skills.get(skill,0)) > int(last_skills.get(best_skill,0)):
			best_skill = skill
	var xp := int(last_skills.get(best_skill,0))
	var level := Progression.level_for_xp(xp)
	var start := Progression.xp_required_for_level(level)
	var required := Progression.xp_required_for_level(level+1)
	if xp_label != null:
		xp_label.text = "%s ур.%d" % [{"archery":"Лук","spear":"Копьё","defense":"Защита"}[best_skill],level]
	if xp_bar != null:
		xp_bar.max_value = maxf(1.0,float(required-start))
		xp_bar.value = float(xp-start)
		xp_bar.tooltip_text = "XP %d / %d" % [xp,required]
	practice_label.text = "ВОЖАК %d/180 HP" % alpha_wolf_hp if alpha_wolf_hp > 0 else "Л%d К%d Щ%d · Охота %d/5" % [a,s,d,hunt_progress]
	practice_label.tooltip_text = "Тренировка: %d · XP: лук %d, копьё %d, защита %d" % [
		last_practice_points,int(last_skills.get("archery",0)),
		int(last_skills.get("spear",0)),int(last_skills.get("defense",0))]

func _create_menu() -> void:
	top_actions = HBoxContainer.new()
	top_actions.name = "QuickMenu"
	top_actions.add_theme_constant_override("separation", 5)
	add_child(top_actions)
	for entry in [["bag", "inventory", "Рюкзак"], ["build", "build", "Строительство"], ["craft", "craft", "Крафт"], ["skills", "skills", "Навыки"], ["settings", "settings", "Настройки"]]:
		var key: String = entry[1]
		var button := Button.new()
		button.name = "Menu_%s" % key
		button.text = ""
		button.tooltip_text = entry[2]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(49, 49)
		button.add_theme_stylebox_override("normal", _card(Color("142329", 0.84), Color("cfbd96", 0.30), 14, 0))
		button.add_theme_stylebox_override("hover", _card(Color("30423e", 0.94), GOLD, 14, 0))
		button.add_theme_stylebox_override("pressed", _card(Color("61573d", 0.96), GOLD, 14, 0))
		if key == "skills":
			button.pressed.connect(func() -> void: open_skills.emit())
		else:
			button.pressed.connect(_open.bind(key))
		top_actions.add_child(button)
		var icon: Control = Glyph.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.setup(entry[0], GOLD)
		button.add_child(icon)
		# Button isn't a Container. Explicit offsets avoid uncontrolled sizing.
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 10
		icon.offset_top = 10
		icon.offset_right = -10
		icon.offset_bottom = -10
		top_controls[key] = button
		if key == "craft":
			craft_badge = PanelContainer.new()
			craft_badge.name = "CraftReadyBadge"
			craft_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
			craft_badge.add_theme_stylebox_override("panel", _card(Color("38724d", 0.98), Color("b1f6ad", 0.95), 10, 2))
			button.add_child(craft_badge)
			craft_badge_label = Style.label("0", 12, Color("f0ffe8"))
			craft_badge_label.name = "Count"
			craft_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			craft_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			craft_badge_label.custom_minimum_size = Vector2(16, 17)
			craft_badge.add_child(craft_badge_label)
			craft_badge.position = Vector2(30, -4)
			craft_badge.visible = false

func _create_hotbar() -> void:
	hotbar = HotbarScene.instantiate()
	hotbar.name = "EquipmentHotbar"
	hotbar.state = state
	hotbar.item_selected.connect(func(id: String) -> void: item_selected.emit(id))
	add_child(hotbar)
	selected_tool_hint = Style.label("", 11, CREAM)
	selected_tool_hint.name = "SelectedToolHint"
	selected_tool_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selected_tool_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(selected_tool_hint)

func _create_touch() -> void:
	touch_layer = Control.new()
	touch_layer.name = "TouchControls"
	touch_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(touch_layer)
	joystick = preload("res://ui/preview_joystick.gd").new()
	joystick.name = "MovementJoystick"
	joystick.custom_minimum_size = Vector2(116, 116)
	joystick.size = Vector2(116, 116)
	touch_layer.add_child(joystick)
	action_buttons = Control.new()
	action_buttons.name = "ActionCluster"
	action_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_layer.add_child(action_buttons)
	for entry in [["attack", "УДАР", 76], ["gather", "СБОР", 63], ["jump", "ПРЫЖОК", 63], ["sprint", "БЕГ", 63], ["ability", "ЗОВ", 63], ["spell", "ОГОНЬ", 62], ["target", "ЦЕЛЬ", 62]]:
		var id: String = entry[0]
		var diameter: int = entry[2]
		var button := Button.new()
		button.name = "Action_%s" % id
		button.custom_minimum_size = Vector2(diameter, diameter)
		button.size = button.custom_minimum_size
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "Выбрать следующего врага; нажмите на моба для точного выбора" if id == "target" else entry[1]
		button.text = ""
		button.add_theme_stylebox_override("normal", _card(Color("1b2b2d", 0.80) if id != "attack" else Color("9c7653", 0.91), Color("e5bd77", 0.57), diameter / 2, 0))
		button.add_theme_stylebox_override("pressed", _card(Color("af8c61", 0.96), GOLD, diameter / 2, 0))
		button.add_theme_stylebox_override("hover", _card(Color("42534c", 0.96), GOLD, diameter / 2, 0))
		button.pressed.connect(_touch_action.bind(id))
		action_buttons.add_child(button)
		var icon: Control = Glyph.new()
		icon.setup(id, CREAM if id == "attack" else GOLD)
		icon.position = Vector2((diameter - 36) * 0.5, 3)
		icon.size = Vector2(36, 36)
		button.add_child(icon)
		var caption := Style.label(entry[1], 10, CREAM)
		caption.name = "Caption"
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.position = Vector2(0, diameter - 22)
		caption.size = Vector2(diameter, 16)
		button.add_child(caption)
		action_controls[id] = button
		if id == "spell":
			button.visible = false

func set_spell(index: int) -> void:
	if action_controls.has("spell"):
		action_controls["spell"].get_node("Caption").text = ["ОГОНЬ","ЛЁД","ГРОМ"][clampi(index,0,2)]

func set_shield_mode(equipped: bool) -> void:
	if not action_controls.has("attack"):
		return
	# Shield is an offhand item; it must not overwrite the main attack label.
	_update_attack_caption()

func _update_attack_caption() -> void:
	if not action_controls.has("attack"):
		return
	var button: Button = action_controls["attack"]
	var caption: Label = button.get_node("Caption")
	match combat_mode:
		"bow":
			caption.text = "ВЫСТРЕЛ"
			button.tooltip_text = "Лук · наведите прицел · 1 стрела за выстрел"
		"spear":
			caption.text = "УКОЛ"
			button.tooltip_text = "Копьё · цель впереди · до 4,5 м"
		_:
			caption.text = "МАГИЯ" if state.selected_avatar == "mage" else "УДАР"
			button.tooltip_text = "Заклинание выбранной стихии" if state.selected_avatar == "mage" else "Атаковать"

func set_combat_mode(item: String) -> void:
	combat_mode = item
	_update_attack_caption()

func set_hero_class(choice: int) -> void:
	if not action_controls.has("ability"):
		return
	var labels := ["ЗОВ","РЫВОК","ЛЕЧИТЬ"]
	var ability: Button = action_controls["ability"]
	ability.get_node("Caption").text = labels[clampi(choice,0,2)]
	ability.tooltip_text = ["Рыцарь: привлечь волков со щитом (Q)",
		"Разбойник: рывок без прохождения сквозь препятствия (Q)",
		"Маг: вылечить союзника за 40 маны (Q)"][clampi(choice,0,2)]
	if action_controls.has("spell"):
		action_controls["spell"].visible = choice == 2
	_update_attack_caption()
	_layout()

func _create_warning() -> void:
	warning_detail = Style.label("", 14, Color("ffe0af"))
	warning_detail.name = "ConnectionWarning"
	warning_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	warning_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warning_detail.add_theme_stylebox_override("normal", _card(Color("543b2c", 0.88), Color("e8b37f", 0.55), 10, 8))
	warning_detail.visible = false
	add_child(warning_detail)

func _create_raid_ui() -> void:
	raid_banner = Style.label("", 14, CREAM)
	raid_banner.name = "CoopRaidBanner"
	raid_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raid_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	raid_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	raid_banner.add_theme_stylebox_override("normal", _card(Color("17272b", 0.84), Color("d4b781", 0.48), 13, 5))
	raid_banner.visible = false
	add_child(raid_banner)
	heal_button = Button.new()
	heal_button.name = "HealAtCampfire"
	heal_button.text = "✚ Лечиться · 2 травы"
	heal_button.tooltip_text = "Возле костра восстановить 35 HP за 2 травы"
	heal_button.focus_mode = Control.FOCUS_NONE
	heal_button.add_theme_stylebox_override("normal", _card(Color("294139", 0.88), Color("9bc69e", 0.66), 12, 5))
	heal_button.add_theme_stylebox_override("pressed", _card(Color("436650", 0.97), Color("bce4b4"), 12, 5))
	heal_button.pressed.connect(func() -> void: action_requested.emit("heal"))
	heal_button.visible = false
	add_child(heal_button)
	repair_button = Button.new()
	repair_button.name = "RepairCamp"
	repair_button.text = "Ремонт · 2 дерева + 1 камень"
	repair_button.tooltip_text = "Возле костра восстановить 30 HP лагеря"
	repair_button.focus_mode = Control.FOCUS_NONE
	repair_button.pressed.connect(func() -> void: action_requested.emit("repair"))
	repair_button.visible = false
	add_child(repair_button)

func set_camp_health(hp: int, maximum: int) -> void:
	camp_health = clampi(hp, 0, maximum)
	repair_button.tooltip_text = "Лагерь %d/%d HP · ремонт +30" % [camp_health, maximum]
	_update_repair_visibility()

func _create_quick_consumables() -> void:
	quick_consumables = HBoxContainer.new()
	quick_consumables.name = "QuickConsumables"
	quick_consumables.add_theme_constant_override("separation", 5)
	add_child(quick_consumables)
	for kind in ["bandage", "grilled_meat", "repair_kit", "mana_potion"]:
		var button := Button.new()
		button.name = "Quick_%s" % kind
		button.custom_minimum_size = Vector2(70, 36)
		button.focus_mode = Control.FOCUS_NONE
		Style.button(button)
		button.add_theme_stylebox_override("normal", _card(Color("202a30", 0.91), Color("5f655f"), 10, 5))
		button.add_theme_stylebox_override("disabled", _card(Color("20282b", 0.70), Color("454b4b"), 10, 5))
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(func() -> void: action_requested.emit(kind))
		quick_consumables.add_child(button)
		quick_buttons[kind] = button

func _create_zoom_controls() -> void:
	zoom_controls = HBoxContainer.new()
	zoom_controls.name = "CameraZoomControls"
	add_child(zoom_controls)
	for entry in [["+", -1.3], ["−", 1.3]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size = Vector2(38, 38)
		button.tooltip_text = "Приблизить" if entry[1] < 0 else "Отдалить"
		Style.button(button)
		button.pressed.connect(zoom_requested.emit.bind(float(entry[1])))
		zoom_controls.add_child(button)

func _refresh_quick_consumables() -> void:
	if state == null or quick_buttons.is_empty():
		return
	var alive := state.health_known and state.health > 0
	var hurt := alive and state.health < state.max_health
	for kind in quick_buttons:
		var button: Button = quick_buttons[kind]
		var count := state.amount(kind)
		var repair_context := camp_health > 0 and camp_health < 120 and state.near_campfire and raid_banner.visible and raid_banner.text.contains("НОЧНАЯ")
		# Keep combat actions readable: show only consumables the player owns.
		# Repair is a contextual camp action, not a permanent combat button.
		button.visible = count > 0 and (kind != "mana_potion" or state.selected_avatar == "mage") and (kind != "repair_kit" or repair_context)
		var reason := ""
		if count <= 0:
			reason = "Нет предмета"
		elif not alive:
			reason = "Ожидание персонажа"
		elif kind == "bandage" and not hurt:
			reason = "HP полное"
		elif kind == "mana_potion" and (not mana_label.visible or not _mana_needs_refill):
			reason = "Только для мага при неполной мане"
		elif kind == "repair_kit" and not repair_context:
			reason = "Ремонт: ночью у повреждённого лагеря возле костра"
		elif state.loading:
			reason = "Ожидание сервера"
		button.text = {"bandage":"✚", "grilled_meat":"Еда", "repair_kit":"Рем.", "mana_potion":"MP"}[kind] + " ×%d" % count
		button.disabled = not reason.is_empty()
		button.tooltip_text = reason if not reason.is_empty() else {"bandage":"Восстановить 40 HP", "grilled_meat":"Еда: +25 HP и регенерация", "repair_kit":"Восстановить 60 HP лагеря", "mana_potion":"Восстановить 35 MP"}[kind]
	quick_consumables.visible = quick_buttons.values().any(func(button: Button) -> bool: return button.visible)
	_layout()

func _update_repair_visibility() -> void:
	if repair_button == null or state == null:
		return
	repair_button.visible = camp_health > 0 and camp_health < 120 and state.near_campfire and state.health_known and state.health > 0 and state.amount("wood") >= 2 and state.amount("stone") >= 1 and raid_banner.visible and raid_banner.text.contains("НОЧНАЯ")

func set_raid_status(phase: String, round_number: int, kills: int, goal: int, seconds: int) -> void:
	if raid_banner == null:
		return
	var minutes := seconds / 60
	var remainder := seconds % 60
	var clock := "%02d:%02d" % [minutes, remainder]
	match phase:
		"prepare":
			raid_banner.text = "ДЕНЬ %d · Подготовьте лагерь  %s" % [round_number, clock]
		"night":
			raid_banner.text = "НОЧНАЯ АТАКА · Волки %d/%d  %s" % [kills, goal, clock]
		"intermission":
			raid_banner.text = "ПЕРЕДЫШКА · %s" % clock
	raid_banner.visible = true
	raid_banner.add_theme_color_override("font_color", Color("ffcf91") if phase == "night" else CREAM)

func _card(bg: Color, edge: Color = Color.TRANSPARENT, radius: int = 12, pad: int = 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = edge
	box.set_border_width_all(1 if edge.a > 0.0 else 0)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(pad)
	return box

func refresh() -> void:
	if state == null or status_panel == null:
		return
	var ready_count := state.ready_recipe_count()
	if craft_badge != null:
		craft_badge.visible = ready_count > 0
		craft_badge_label.text = str(ready_count)
		top_controls["craft"].tooltip_text = "Крафт · хватает материалов для %d рецептов (изготавливаются возле костра)" % ready_count
	var names := {"knight": "РЫЦАРЬ", "rogue": "РАЗБОЙНИК", "mage": "МАГ"}
	avatar_name.text = names.get(state.selected_avatar, state.selected_avatar.to_upper())
	health_detail.text = ("%d/%d" % [state.health, state.max_health]) if state.health_known else "—"
	health_bar.max_value = maxi(1, state.max_health)
	health_bar.value = state.health if state.health_known else 0
	var status := state.connection_status.to_lower()
	var failed := status.contains("update") or status.contains("cannot") or status.contains("failed") or status.contains("unavailable") or status.contains("disconnected") or status.contains("invalid") or status.contains("unable") or status.contains("untrusted")
	status_detail.text = "●" if state.health_known else "◌"
	status_detail.add_theme_color_override("font_color", SAGE if state.health_known else GOLD)
	warning_detail.visible = failed or (state.health_known and state.health == 0)
	if state.health_known and state.health == 0:
		warning_detail.text = "Возрождение..."
	elif failed:
		warning_detail.text = "Требуется обновление клиента" if status.contains("update") else state.connection_status
	for kind in ["wood", "stone", "herb"]:
		var counter: Label = resource_counts[kind]
		counter.text = str(state.amount(kind))
	match combat_mode:
		"bow":
			selected_tool_hint.text = "ЛУК  ·  %d СТРЕЛ  ·  12 М  ·  ВЫСТРЕЛ" % state.amount("arrow")
		"spear":
			selected_tool_hint.text = "КОПЬЁ  ·  ДО 4,5 М  ·  J / ЛКМ / УКОЛ"
		"wooden_staff":
			selected_tool_hint.text = "ПОСОХ  ·  +3 УРОНА МАГИЕЙ"
		"staff":
			selected_tool_hint.text = "МАГИЧЕСКИЙ ПОСОХ"
		"shield":
			selected_tool_hint.text = "ЩИТ  ·  ЗАЩИТА  ·  Q — УМЕНИЕ"
		"axe":
			selected_tool_hint.text = "КАМЕННЫЙ ТОПОР"
		_:
			selected_tool_hint.text = ""
	selected_tool_hint.visible = not selected_tool_hint.text.is_empty()
	heal_button.visible = state.health_known and state.health > 0 and state.health < 100 and state.near_campfire and state.amount("herb") >= 2
	_update_repair_visibility()
	_refresh_quick_consumables()
	touch_layer.visible = show_touch_controls
	_layout()

func _layout() -> void:
	if status_panel == null or size.x < 100 or size.y < 100:
		return
	var inset := _safe_insets()
	var compact := size.y < 490
	var margin := 7.0
	var status_w := 210.0 if compact else 220.0
	var status_h := maxf(72.0, status_panel.get_combined_minimum_size().y)
	status_panel.position = Vector2(inset.x, inset.y)
	status_panel.size = Vector2(status_w, status_h)
	resources_panel.position = Vector2(inset.x, inset.y + status_h + margin)
	resources_panel.size = resources_panel.get_combined_minimum_size()
	progress_panel.position = Vector2(inset.x + 3, resources_panel.position.y + resources_panel.size.y + 3)
	progress_panel.size = progress_panel.get_combined_minimum_size()
	top_actions.position = Vector2(size.x - inset.z - top_actions.get_combined_minimum_size().x, inset.y + 1)
	top_actions.size = top_actions.get_combined_minimum_size()
	var hot_size := hotbar.get_combined_minimum_size()
	hotbar.position = Vector2((size.x - hot_size.x) * 0.5, size.y - inset.w - hot_size.y)
	hotbar.size = hot_size
	selected_tool_hint.size = Vector2(hot_size.x, 19)
	selected_tool_hint.position = Vector2(hotbar.position.x, hotbar.position.y - 23)
	raid_banner.size = Vector2(minf(310.0, size.x * 0.48), 37)
	raid_banner.position = Vector2((size.x - raid_banner.size.x) * 0.5, hotbar.position.y - 78)
	heal_button.size = Vector2(172, 37)
	var info_bottom := progress_panel.position.y + progress_panel.size.y
	heal_button.position = Vector2(inset.x, info_bottom + 8)
	repair_button.size = Vector2(216, 37)
	repair_button.position = Vector2(inset.x, heal_button.position.y + (43 if heal_button.visible else 0))
	if quick_consumables != null:
		quick_consumables.size = quick_consumables.get_combined_minimum_size()
		quick_consumables.position = Vector2(inset.x, minf(size.y - inset.w - 45 - quick_consumables.size.y, info_bottom + (46 if heal_button.visible or repair_button.visible else 14)))
	if zoom_controls != null:
		zoom_controls.visible = show_touch_controls
		zoom_controls.size = zoom_controls.get_combined_minimum_size()
		zoom_controls.position = Vector2(size.x - inset.z - zoom_controls.size.x, inset.y + 62)
	joystick.size = Vector2(116, 116)
	joystick.position = Vector2(inset.x + 6, size.y - inset.w - joystick.size.y + 5)
	action_buttons.position = Vector2.ZERO
	action_buttons.size = size
	# Three compact rows: movement/combat at thumb level, class actions above.
	# Keep the main attack at the outer edge for simultaneous joystick + attack.
	var right := size.x - inset.z - 76
	var lower := size.y - inset.w - 102
	var positions := {
		"attack": Vector2(right, lower - 12),
		"gather": Vector2(right - 72, lower + 2),
		"jump": Vector2(right + 6, lower - 88),
		"sprint": Vector2(right - 68, lower - 79),
		"ability": Vector2(right - 140, lower - 79),
		"spell": Vector2(right - 140, lower - 150),
		"target": Vector2(right - 140, lower - 150),
	}
	for id in positions:
		var button: Button = action_controls[id]
		# Mage spell and target cycling share a row but never overlap.
		button.position = positions[id] + (Vector2(-70, 0) if id == "target" and action_controls["spell"].visible else Vector2.ZERO)
		button.size = button.custom_minimum_size
	warning_detail.size = Vector2(minf(400, size.x * 0.55), 48)
	warning_detail.position = Vector2(inset.x, info_bottom + 8)

func _safe_insets() -> Vector4:
	var values := Vector4(15, 15, 15, 17)
	if not OS.has_feature("mobile") and not OS.get_cmdline_user_args().has("--test-mobile-ui") and not OS.get_cmdline_user_args().has("--test-live-ui"):
		return values
	var screen := DisplayServer.screen_get_size()
	if screen.x > 0 and screen.y > 0:
		var safe := DisplayServer.get_display_safe_area()
		values.x = maxf(22, float(safe.position.x) / screen.x * size.x + 8)
		values.y = maxf(49, float(safe.position.y) / screen.y * size.y + 8)
		values.z = maxf(22, float(screen.x - safe.end.x) / screen.x * size.x + 8)
		values.w = maxf(30, float(screen.y - safe.end.y) / screen.y * size.y + 8)
	else:
		values = Vector4(22, 49, 22, 30)
	return values

func _open(kind: String) -> void:
	match kind:
		"inventory": open_inventory.emit()
		"build": open_building.emit()
		"craft": open_crafting.emit()
		"settings": open_settings.emit()

func _touch_action(kind: String) -> void:
	action_requested.emit(kind)
