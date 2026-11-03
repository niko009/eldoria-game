extends SceneTree
# No healing/raid loot may be acknowledged when persistence refuses a write.
const GAME := preload("res://Main.tscn")
class RejectingStore:
	extends RefCounted
	var profiles: Dictionary = {}
	var buildings: Dictionary = {}
	var last_error := "isolated test rejecting persistence"
	func save_snapshot(_resources: Dictionary, _world: Node3D) -> bool:
		return false

func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	game._host()
	var id: int = game.own_id
	var key := "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
	game.player_identity_keys[id] = key
	game.player_health[id] = 50
	game.player_inventories[id] = {"wood":0,"stone":2,"herb":4,"axe":0}
	game.persistent_profiles[key] = {"avatar":0,"inventory":game.player_inventories[id].duplicate(true)}
	game.placed_buildings[123] = {"kind":"campfire","x":0.0,"z":0.0}
	var old_inv: Dictionary = game.player_inventories[id].duplicate(true)
	game.world_store = RejectingStore.new()
	if game._heal_on_server(id):
		_fail("healing acknowledged despite failed snapshot")
		return
	if int(game.player_health[id]) != 50 or game.player_inventories[id] != old_inv:
		_fail("healing failed to roll back player HP/herbs")
		return
	if game.persistent_profiles[key]["inventory"] != old_inv:
		_fail("healing left a dirty saved profile")
		return
	game._reward_raid_survivors()
	if game.player_inventories[id] != old_inv or game.persistent_profiles[key]["inventory"] != old_inv:
		_fail("raid loot was granted despite failed persistence")
		return
	game.world_store = null
	if not game._heal_on_server(id) or int(game.player_health[id]) != 85:
		_fail("healing failed after persistence recovery")
		return
	game._reward_raid_survivors()
	if int(game.player_inventories[id]["stone"]) != 4 or int(game.player_inventories[id]["herb"]) != 4:
		_fail("success reward did not persist expected amount")
		return
	game._disconnect()
	print("TASK039 RAID FAULTS PASS healing and loot rollback on persistence failure")
	quit(0)
func _fail(message: String) -> void:
	printerr("TASK039 RAID FAULTS FAIL: "+message)
	quit(1)
