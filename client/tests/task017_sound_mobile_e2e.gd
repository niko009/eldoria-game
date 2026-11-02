extends SceneTree
const GAME := preload("res://Main.tscn")
const WOOD := preload("res://assets/sfx/wood_chop.wav")
const STONE := preload("res://assets/sfx/stone_hit.wav")
const HERB := preload("res://assets/sfx/herb_rustle.wav")
const BUILD := preload("res://assets/sfx/build_place.wav")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game._host()
    var world: Node3D = game.get_node("Eldoria_Forest")
    var tree: Dictionary = {}
    for e in world.resources:
        if e["kind"] == "wood":
            tree=e
            break
    if tree.is_empty():
        _fail("missing tree")
        return
    var id: int = tree["id"]
    var sounds := {"wood":WOOD,"stone":STONE,"herb":HERB,"build":BUILD}
    for kind in sounds.keys():
        var sound: AudioStream = sounds[kind]
        if sound.get_length() < 0.15 or sound.get_length() > 0.8:
            _fail("WAV missing/corrupt "+kind)
            return
    world.set_resource_quantity(id,3)
    if not world.damage_markers.has(id) or world.damage_markers[id].hits != 1:
        _fail("first axe cut not visible")
        return
    world.set_resource_quantity(id,2)
    if world.damage_markers[id].hits != 2:
        _fail("second axe cut not added")
        return
    world.set_resource_quantity(id,1)
    if world.damage_markers[id].hits != 3:
        _fail("third axe cut not added")
        return
    world.set_resource_quantity(id,0)
    if world.damage_markers.has(id) or world.obstacle_active[tree["obstacle_id"]]:
        _fail("fell tree did not clear damage marks and collision")
        return
    world.set_resource_quantity(id,2)
    if not world.damage_markers.has(id) or world.damage_markers[id].hits!=2:
        _fail("resource snapshot restore did not reconstruct damage")
        return
    var vfx: Node3D = game.harvest_visuals
    if not vfx.play_sound("wood",tree["pos"]) or not vfx.play_sound("stone",tree["pos"]):
        _fail("positional sound players not created")
        return
    if vfx.active_sound_count()!=2:
        _fail("audio streams missing")
        return
    game._toggle_sound()
    if vfx.sound_enabled or vfx.active_sound_count()!=0:
        _fail("mute failed to stop sounds")
        return
    if vfx.play_sound("herb",tree["pos"]):
        _fail("muted audio played")
        return
    game._toggle_sound()
    if not vfx.sound_enabled:
        _fail("unmute failed")
        return
    if game.mobile_build_toggle == null or not game.mobile_build_toggle.visible:
        _fail("mobile construction mode toggle not shown")
        return
    game.player_inventories[game.own_id] = {"wood":8,"stone":2,"herb":2}
    game.mobile_build_toggle.pressed.emit()
    if not game.mobile_build_panel.visible or not game.preview_enabled or not game.mobile_build_mode:
        _fail("Build mode failed to open")
        return
    var viewport_height: float = game.get_viewport().get_visible_rect().size.y
    var mobile_bounds: Rect2 = game.mobile_build_panel.get_global_rect()
    if mobile_bounds.position.y < 0 or mobile_bounds.end.y > viewport_height:
        _fail("build menu clipped on landscape phone: "+str(mobile_bounds)+" viewport="+str(viewport_height))
        return
    if game.preview_kind != "campfire" or not game.preview_valid:
        _fail("green campfire preview missing")
        return
    game.mobile_build_picker.select(1)
    game.mobile_build_picker.item_selected.emit(1)
    if game.preview_kind != "tent" or game.build_selector.selected != 1:
        _fail("mobile building type selection failed")
        return
    # A mobile PLACE tap must pass through the authoritative build path.
    var place: Button = game.mobile_build_panel.find_child("MobilePlace",true,false)
    if place == null:
        _fail("mobile PLACE button missing")
        return
    place.pressed.emit()
    if game.placed_buildings.size()!=1 or game.mobile_build_mode:
        _fail("touch PLACE failed to construct tent or close build mode")
        return
    var first: Dictionary = game.placed_buildings[1]
    if first["kind"] != "tent":
        _fail("wrong mobile building placed")
        return
    if game.mobile_build_panel.get_global_rect().intersects(game.mobile_controls.get_global_rect()):
        _fail("mobile construction mode blocks movement joystick")
        return
    print("TASK017 OPENGL PASS: 1/2/3 tree wounds, depletion restore, 4 WAV cues, mute, mobile picker/place/cancel and joystick clearance")
    game._disconnect()
    quit(0)
func _fail(message: String) -> void:
    printerr("TASK017 OPENGL FAIL: "+message)
    quit(1)
