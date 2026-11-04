extends SceneTree
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    if DisplayServer.get_name() == "headless":
        _fail("real OpenGL renderer required"); return
    var game: Node3D=GAME.instantiate()
    root.add_child(game)
    await process_frame
    game.selected_avatar=1
    game._host()
    game.set_physics_process(false)
    var id: int=game.own_id
    var world: Node3D=game.get_node("Eldoria_Forest")
    var at:=Vector3(0,world.height_at(0,0)+1,0)
    game.players[id].position=at
    var vfx=game.harvest_visuals
    vfx.clear_effects()
    vfx.set_sound_enabled(true)
    var kinds=["step_a","step_b","punch","spear_swing","spear_hit","shield_hit","wolf_hit","obstacle_hit","gear_swish","bow","wolf_bite","wolf_death","heal","dash","taunt","wood","stone","herb","build"]
    for kind in kinds:
        if not vfx.play_sound(kind,at):
            _fail("registered sound missing: "+kind);return
        if vfx.active_sound_count()!=1 or vfx._sounds[0].stream == null:
            _fail("sound was not instantiated: "+kind);return
        if vfx._sounds[0].max_distance!=25.0:
            _fail("sound has no capped spatial range: "+kind);return
        if vfx.play_sound(kind,at):
            _fail("retriggered identical sound ignored cooldown: "+kind);return
        vfx.clear_effects()
    if vfx.play_sound("fake",at) or vfx.play_sound("bow",Vector3.INF):
        _fail("invalid type/position created sound");return
    for i in 6:
        if not vfx.play_sound(kinds[i],at):
            _fail("six sound channels should fit voice budget");return
    if vfx.active_sound_count()!=6 or vfx.play_sound("wolf_bite",at):
        _fail("voice budget exceeded six simultaneous sounds");return
    vfx.set_sound_enabled(false)
    if vfx.active_sound_count()!=0 or vfx.play_sound("bow",at):
        _fail("mute failed to stop all sounds");return
    vfx.set_sound_enabled(true)
    game.player_inventories[id]=game._empty_inventory()
    game.players[id].set_combat_equipped("spear")
    game._play_attack(id)
    if vfx.active_sound_count()!=1 or vfx._sounds[0].stream != load("res://assets/sfx/kenney/spear_swing.ogg"):
        _fail("spear attack visual has no matching sound");return
    vfx.clear_effects()
    game.players[id].set_combat_equipped("bow")
    game.bow_shot_visual(at+Vector3.UP,at+Vector3(5,1,0))
    if vfx.active_sound_count()!=1 or vfx._sounds[0].stream != load("res://assets/sfx/bow_twang.wav"):
        _fail("bow release has no correct audio");return
    vfx.clear_effects()
    game.wolf_alive=true
    game.wolf_position=at+Vector3(2,0,0)
    game.wolf_snapshot(game.wolf_position,60,true,Vector3.ZERO)
    game.wolf_attack_visual(0)
    if vfx.active_sound_count()!=1 or vfx._sounds[0].stream != load("res://assets/sfx/wolf_snarl.wav"):
        _fail("wolf attack has no growl sound");return
    vfx.clear_effects()
    game.wolf_snapshot(game.wolf_position,0,false,Vector3.ZERO)
    if vfx.active_sound_count()!=1 or vfx._sounds[0].stream != load("res://assets/sfx/wolf_death.wav"):
        _fail("wolf death transition has no death sound");return
    game.wolf_snapshot(game.wolf_position,0,false,Vector3.ZERO)
    if vfx.active_sound_count()!=1:
        _fail("dead wolf sound was duplicated by repeated snapshot");return
    vfx.clear_effects()
    game._play_movement_audio(id,Vector3(0.2,0,0),false)
    if vfx.active_sound_count()!=1 or vfx._sounds[0].stream != load("res://assets/sfx/kenney/step_grass_a.ogg"):
        _fail("movement has no footstep sound");return
    game._play_movement_audio(id,Vector3(0.2,0,0),false)
    if vfx.active_sound_count()!=1:
        _fail("footstep spam bypassed per-player cooldown");return
    vfx.clear_effects()
    vfx.play_sound("heal",at)
    if vfx.active_sound_count()!=1 or vfx._sounds[0].stream==null:
        _fail("mage healing audio source missing");return
    vfx.clear_effects()
    print("TASK062 AUDIO OPENGL PASS 19 spatial clips, CC0 foley, max voices, cooldown, mute, spear/bow/wolf/death/footstep event routing")
    quit(0)
func _fail(why: String) -> void:
    printerr("TASK062 AUDIO FAIL: "+why)
    quit(1)
