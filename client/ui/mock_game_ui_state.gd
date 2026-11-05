extends RefCounted
class_name MockGameUiState

signal changed
signal request_build(building_id: String)
signal request_craft(recipe_id: String)
signal request_select_item(item_id: String)
signal request_close

const ITEMS := {
	"wood": {"name": "Древесина", "symbol": "▥"},
	"stone": {"name": "Камень", "symbol": "◆"},
	"herb": {"name": "Трава", "symbol": "✿"},
	"mana_herb": {"name":"Синецвет","symbol":"✧"},
	"axe": {"name": "Каменный топор", "symbol": "⚒"},
	"bandage": {"name": "Повязка", "symbol": "+"},
	"repair_kit": {"name": "Ремкомплект", "symbol": "▣"},
	"spear": {"name":"Копьё","symbol":"|"},
	"bow": {"name":"Лук","symbol":")"},
	"shield": {"name":"Щит","symbol":"◈"},
	"arrow": {"name":"Стрела","symbol":"→"},
	"meat": {"name":"Мясо","symbol":"◒"},
	"hide": {"name":"Шкура","symbol":"▧"},
	"bone": {"name":"Кость","symbol":"⌁"},
	"leather_armor": {"name":"Кожаная броня","symbol":"▣"},
	"grilled_meat": {"name":"Жареное мясо","symbol":"◉"},
	"wooden_staff": {"name":"Деревянный посох","symbol":"✧"},
	"mana_potion": {"name":"Малое зелье маны","symbol":"✦"},
}
# Hotbar is equipment-only. Unimplemented tools are shown as locked previews.
# No inventory quantity badges belong in the hotbar.
const TOOLS := {
	"unarmed": {"name": "Без оружия", "implemented": true},
	"sword": {"name": "Меч · скоро", "implemented": false},
	"pickaxe": {"name": "Кирка · скоро", "implemented": false},
	"axe": {"name": "Каменный топор", "implemented": true},
	"hammer": {"name": "Молот · скоро", "implemented": false},
	"spear": {"name": "Копьё", "implemented": true},
	"shield": {"name": "Щит", "implemented": true},
	"bow": {"name": "Лук", "implemented": true},
	"wooden_staff": {"name": "Посох", "implemented": true},
}
const BUILDINGS := {
	"campfire": {"name": "Костёр", "description": "Тепло и место для отдыха", "cost": {"wood": 3, "stone": 2}},
	"tent": {"name": "Палатка", "description": "Укрытие для путника", "cost": {"wood": 5, "herb": 2}},
}
const RECIPES := {
	"axe": {"name": "Каменный топор", "description": "Рубит 2 древесины за удар · нужен костёр рядом", "cost": {"wood": 2, "stone": 2}},
	"bandage": {"name": "Повязка", "description": "Восстанавливает 40 HP в любом месте", "cost": {"wood": 1, "herb": 2}},
	"repair_kit": {"name": "Ремкомплект", "description": "Восстанавливает 60 HP лагеря рядом с костром", "cost": {"wood": 3, "stone": 2}},
	"spear": {"name":"Копьё","description":"Ближняя атака до 4,5 м · урон 30","cost":{"wood":3,"stone":2}},
	"bow": {"name":"Лук","description":"Прицельный выстрел до 12 м · расходует стрелы","cost":{"wood":4,"herb":2}},
	"shield": {"name":"Щит","description":"Снижает урон волков на 40%","cost":{"wood":4,"stone":1}},
	"arrow": {"name":"Стрела","description":"Боеприпас для лука (1 штука)","cost":{"wood":1,"stone":1}},
	"leather_armor": {"name":"Кожаная броня","description":"Пассивно уменьшает входящий урон на 15%","cost":{"hide":3,"bone":1}},
	"grilled_meat": {"name":"Жареное мясо","description":"Восстанавливает 25 HP и даёт регенерацию здоровья на 30 секунд","cost":{"meat":1,"herb":1}},
	"wooden_staff": {"name":"Деревянный посох","description":"Магия: +3 урона заклинаниям","cost":{"wood":4,"stone":2,"herb":3}},
	"mana_potion": {"name":"Малое зелье маны","description":"В бою восстанавливает 35 MP; кулдаун 12 секунд","cost":{"mana_herb":2,"herb":1}},
}

var inventory: Dictionary = {"wood": 7, "stone": 3, "herb": 1, "axe": 0}
var selected_item := "unarmed"
var selected_avatar := "knight"
var connection_status := "Автономный просмотр"
var loading := false
var near_campfire := true # Standalone Preview starts at a sample crafting station.
var equipped_axe := false
var health := 100
var max_health := 100
var health_known := true # Preview only; live adapter clears this until server snapshot.

func amount(item_id: String) -> int:
	return int(inventory.get(item_id, 0))

func can_afford(cost: Dictionary) -> bool:
	for item_id in cost:
		if amount(item_id) < int(cost[item_id]):
			return false
	return true

# "Ready" means all ingredients have been collected and the item stack is not
# full. The actual craft button still requires a nearby campfire.
func recipe_limit(recipe_id: String) -> int:
	if ["axe", "spear", "bow", "shield", "leather_armor", "wooden_staff"].has(recipe_id):
		return 1
	if recipe_id == "arrow":
		return 40
	return 20

func recipe_materials_ready(recipe_id: String) -> bool:
	if not RECIPES.has(recipe_id):
		return false
	return amount(recipe_id) < recipe_limit(recipe_id) and can_afford(RECIPES[recipe_id]["cost"])

func ready_recipe_count() -> int:
	var total := 0
	for recipe_id in RECIPES:
		if recipe_materials_ready(recipe_id):
			total += 1
	return total

func recipes_ready_first() -> Array[String]:
	var sorted: Array[String] = []
	for ready in [true, false]:
		for recipe_id in RECIPES:
			if recipe_materials_ready(recipe_id) == ready:
				sorted.append(recipe_id)
	return sorted

func can_select_tool(tool_id: String) -> bool:
	if not TOOLS.has(tool_id):
		return false
	if not bool(TOOLS[tool_id]["implemented"]):
		return false
	return not ["axe", "spear", "bow", "shield", "wooden_staff"].has(tool_id) or amount(tool_id) > 0

func select_item(item_id: String) -> void:
	# Legacy inventory material clicks mean empty hands, never a resource hotbar slot.
	var tool_id := "unarmed" if ITEMS.has(item_id) and item_id not in ["axe","spear","bow","shield","wooden_staff"] else item_id
	if not can_select_tool(tool_id):
		return
	if selected_item == tool_id:
		return
	selected_item = tool_id
	request_select_item.emit(tool_id)
	changed.emit()

func set_stock(mode: String) -> void:
	match mode:
		"plenty": inventory = {"wood": 9, "stone": 7, "herb": 5, "axe": 1}
		"scarce": inventory = {"wood": 1, "stone": 0, "herb": 0, "axe": 0}
		"empty": inventory = {"wood": 0, "stone": 0, "herb": 0, "axe": 0}
	if ["axe","spear","bow","shield","wooden_staff"].has(selected_item) and amount(selected_item) == 0:
		select_item("unarmed")
	changed.emit()
