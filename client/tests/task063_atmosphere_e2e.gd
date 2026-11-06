extends SceneTree
const GAME := preload("res://Main.tscn")
const BUILD := preload("res://building_object.gd")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    if DisplayServer.get_name() == "headless":
        _fail("real OpenGL required");return
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game._host()
    game.set_physics_process(false)
    var ambience=game.ambience
    if ambience == null or ambience.camp_lights.size()!=2 or ambience.embers.size()!=2:
        _fail("bounded two-light atmosphere manager absent");return
    var world: Node3D=game.get_node("Eldoria_Forest")
    game._place_building(730,{"kind":"campfire","x":0.0,"z":2.0})
    game._place_building(731,{"kind":"campfire","x":5.0,"z":2.0})
    game._place_building(732,{"kind":"campfire","x":8.0,"z":2.0})
    game._place_building(733,{"kind":"tent","x":2.0,"z":1.0})
    ambience.update_campfires(game.building_nodes,Vector3.ZERO)
    if ambience.active_light_count()!=2 or not ambience.embers[0].emitting or not ambience.embers[1].emitting:
        _fail("nearest two fires not lit in HIGH");return
    if ambience.camp_lights[0].shadow_enabled or ambience.camp_lights[1].shadow_enabled:
        _fail("campfires turned on expensive shadow rendering");return
    if ambience.camp_lights[0].position.distance_to(game.building_nodes[730].position+Vector3.UP*0.68)>0.1:
        _fail("ambience did not pick nearest fire");return
    ambience.set_high_detail(false)
    if ambience.active_light_count()!=0 or ambience.embers[0].emitting:
        _fail("Android LOW leaves point lights or particles active");return
    ambience.set_high_detail(true)
    ambience.update_campfires(game.building_nodes,Vector3(90,0,90))
    if ambience.active_light_count()!=0:
        _fail("distant campfires incorrectly rendered");return
    ambience.update_campfires(game.building_nodes,Vector3.ZERO)
    var environment: Environment=world.environment_node.environment
    var sky: ShaderMaterial=environment.sky.sky_material
    game._apply_raid_lighting("night")
    if not ambience.night or game._lighting_tween==null:
        _fail("night transition did not start");return
    await create_timer(1.35).timeout
    if absf(game.sunlight.light_energy-0.42)>0.02 or absf(environment.fog_density-0.0025)>0.0002:
        _fail("night energy/fog values incorrect");return
    if float(sky.get_shader_parameter("night_mix"))<0.98:
        _fail("night shader did not reach evening color");return
    ambience.update_campfires(game.building_nodes,Vector3.ZERO)
    if ambience.camp_lights[0].light_energy < 0.88:
        _fail("campfire did not brighten at night");return
    game._apply_raid_lighting("night")
    if game._lighting_tween != null and game._lighting_tween.is_running():
        _fail("repeated raid status restarted same lighting transition");return
    game._apply_raid_lighting("prepare")
    await create_timer(1.35).timeout
    if absf(game.sunlight.light_energy-0.82)>0.02 or absf(environment.fog_density-0.0016)>0.0002:
        _fail("daylight/fog not restored");return
    if float(sky.get_shader_parameter("night_mix")) > 0.02:
        _fail("day shader still contains night mix");return
    game._clear_buildings()
    ambience.update_campfires(game.building_nodes,Vector3.ZERO)
    if ambience.active_light_count()!=0:
        _fail("deleted campfire leaves local light");return
    game._disconnect()
    if ambience.active_light_count()!=0:
        _fail("disconnect leaves bright lights around camp");return
    print("TASK063 ATMOSPHERE OPENGL PASS smooth day/night sky and fog, nearest two warm camp lights, no shadows, Android LOW disables lights, cleanup")
    quit(0)
func _fail(why: String) -> void:
    printerr("TASK063 ATMOSPHERE FAIL: "+why)
    quit(1)
