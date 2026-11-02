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
	"axe": {"name": "Каменный топор", "symbol": "⚒"},
}
const BUILDINGS := {
	"campfire": {"name": "Костёр", "description": "Тепло и место для отдыха", "cost": {"wood": 3, "stone": 2}},
	"tent": {"name": "Палатка", "description": "Укрытие для путника", "cost": {"wood": 5, "herb": 2}},
}
const RECIPES := {
	"axe": {"name": "Каменный топор", "description": "Рубит 2 древесины за удар · нужен костёр рядом", "cost": {"wood": 2, "stone": 2}},
}

var inventory: Dictionary = {"wood": 7, "stone": 3, "herb": 1, "axe": 0}
var selected_item := "wood"
var selected_avatar := "knight"
var connection_status := "Автономный просмотр"
var loading := false
var near_campfire := true # Standalone Preview starts at a sample crafting station.

func amount(item_id: String) -> int:
	return int(inventory.get(item_id, 0))

func can_afford(cost: Dictionary) -> bool:
	for item_id in cost:
		if amount(item_id) < int(cost[item_id]):
			return false
	return true

func select_item(item_id: String) -> void:
	if not ITEMS.has(item_id):
		return
	selected_item = item_id
	request_select_item.emit(item_id)
	changed.emit()

func set_stock(mode: String) -> void:
	match mode:
		"plenty": inventory = {"wood": 9, "stone": 7, "herb": 5, "axe": 1}
		"scarce": inventory = {"wood": 1, "stone": 0, "herb": 0, "axe": 0}
		"empty": inventory = {"wood": 0, "stone": 0, "herb": 0, "axe": 0}
	changed.emit()
