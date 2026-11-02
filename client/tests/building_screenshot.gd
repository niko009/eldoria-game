extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
    call_deferred("_render")
func _render() -> void:
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    var world: Node3D = game.get_node("Eldoria_Forest")
    var camp := Vector3(0,world.height_at(0,-4),-4)
    var tent := Vector3(-4,world.height_at(-4,0),0)
    game._place_building(1,{"kind":"campfire","x":camp.x,"z":camp.z})
    game._place_building(2,{"kind":"tent","x":tent.x,"z":tent.z})
    game._spawn(3,Vector3(2,1,1),0)
    game.camera.position = Vector3(3.5,6.5,12)
    game.camera.look_at(Vector3(-2,1.3,-2),Vector3.UP)
    for i in range(7):
        await process_frame
    var frame := root.get_texture().get_image()
    var output := "/home/coder/eldoria-task001/builds/eldoria-v050-camp.png"
    var err := frame.save_png(output)
    if err != OK:
        printerr("BUILD SCREENSHOT FAIL "+str(err))
        quit(1)
        return
    print("BUILD SCREENSHOT PASS "+output)
    quit(0)
