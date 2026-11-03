extends SceneTree
# Real Godot scene screenshot of a test-host cooperative defense, no production.
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var game: Node3D = GAME.instantiate()
	root.add_child(game)
	await process_frame
	game._host()
	var player_id: int = game.own_id
	var world: Node3D = game.get_node("Eldoria_Forest")
	game._place_building(501, {"kind":"campfire","x":0.0,"z":-4.0})
	game._place_building(502, {"kind":"tent","x":-4.0,"z":0.0})
	game._spawn(502, Vector3(-3,world.height_at(-3,-2)+1,-2), 2)
	game.players[player_id].position = Vector3(1,world.height_at(1,-2)+1,-2)
	game.player_inventories[player_id] = {"wood":12,"stone":6,"herb":5,"axe":1}
	game.inventory_snapshot(game.player_inventories[player_id])
	game.health_snapshot(70,100)
	game.live_ui.set_near_campfire(true)
	game.raid.phase = "night"
	game.raid.round = 2
	game.raid.kills = 1
	game.raid.deadline_ms = Time.get_ticks_msec() + 75000
	game.raid_state({"phase":"night","round":2,"kills":1,"goal":4,"seconds":75})
	game.camera.position = Vector3(4.6,5.1,10.1)
	game.camera.look_at(Vector3(-1.2,1.0,-1.8))
	var at := Vector3(-1.1,world.height_at(-1.1,-3.5)+0.1,-3.5)
	game.wolf_snapshot(at,60,true,Vector3.ZERO)
	# Slow software OpenGL rendering can consume many seconds per screenshot;
	# prevent this isolated visual probe from killing the demonstration hero.
	game.wolf_last_hit_at = Time.get_ticks_msec() + 120000
	for i in range(20):
		await process_frame
	var output := "/tmp/eldoria-039-raid-night.png"
	var args := OS.get_cmdline_user_args()
	var index := args.find("--screenshot")
	if index >= 0 and index+1 < args.size():
		output = args[index+1]
	var picture := root.get_texture().get_image()
	var status := picture.save_png(output)
	print("TASK039 REAL GODOT NIGHT FRAME ",picture.get_size()," path=",output," status=",status)
	quit(0 if status == OK else 1)
