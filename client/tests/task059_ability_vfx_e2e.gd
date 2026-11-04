extends SceneTree
const GAME := preload("res://Main.tscn")
const HERO := preload("res://hero_classes.gd")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    if DisplayServer.get_name() == "headless":
        _fail("requires actual OpenGL");return
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game.selected_avatar=HERO.MAGE
    game._host()
    game.set_physics_process(false)
    var id: int = game.own_id
    var world: Node3D = game.get_node("Eldoria_Forest")
    var start := Vector3(0,world.height_at(0,0)+1,0)
    game.players[id].position=start
    game.player_health[id]=100
    var rogue := 5599
    game._spawn(rogue,start+Vector3(0,0,1),HERO.ROGUE)
    game.player_health[rogue]=50
    game.player_inventories[rogue]=game._empty_inventory()
    game.hero_mana[id]=100.0
    var vfx = game.harvest_visuals
    vfx.set_sound_enabled(false)
    if not game._hero_ability_on_server(id,Vector3.ZERO):
        _fail("validated Mage heal was refused");return
    if vfx.ability_burst_count() != 1 or game.players[id].current_clip != "Spellcast_Shoot":
        _fail("validated spell did not play unique visual effect");return
    var heal_node: Node3D=vfx._ability_bursts[0]
    if heal_node.name != "Ability_heal" or heal_node.position.distance_to(game.players[rogue].position+Vector3.UP*0.07)>0.01:
        _fail("healing ring not placed on injured ally");return
    if heal_node.get_node("AbilitySparks").amount != 16:
        _fail("HIGH healing particles mismatch");return
    if game._hero_ability_on_server(id,Vector3.ZERO) or vfx.ability_burst_count() != 1:
        _fail("rejected cooldown created fake healing visual");return
    game._hero_ability_on_server(rogue,Vector3.ZERO)
    if vfx.ability_burst_count() != 1:
        _fail("invalid rogue dash produced particles");return
    if not game._hero_ability_on_server(rogue,Vector3.RIGHT):
        _fail("valid rogue dash refused");return
    if vfx.ability_burst_count() != 2 or vfx._ability_bursts[1].name != "Ability_dash":
        _fail("rogue dash effect missing");return
    vfx.set_combat_detail(false)
    if not vfx.play_ability_effect("taunt",start) or vfx._ability_bursts[2].get_node("AbilitySparks").amount!=5:
        _fail("LOW defender aura has wrong particle budget");return
    if not vfx.play_ability_effect("dash",start) or vfx.ability_burst_count() != 4:
        _fail("ability effect pool does not fill to four");return
    if vfx.play_ability_effect("heal",start) or vfx.play_ability_effect("bogus",start) or vfx.play_ability_effect("heal",Vector3.INF):
        _fail("ability effect bypassed limits or payload checks");return
    await create_timer(0.78).timeout
    if vfx.ability_burst_count() != 0:
        _fail("effects did not self-clean after animation");return
    vfx.play_ability_effect("taunt",start)
    vfx.clear_effects()
    if vfx.ability_burst_count() != 0:
        _fail("disconnect cleanup retained class VFX");return
    print("TASK059 ABILITY VFX OPENGL PASS Mage heal on injured ally, Rogue dash, Knight aura, server cooldown, Low/High caps, cleanup")
    quit(0)
func _fail(message: String) -> void:
    printerr("TASK059 ABILITY VFX FAIL: "+message)
    quit(1)
