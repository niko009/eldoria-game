extends SceneTree
const ACTOR := preload("res://animated_actor.gd")
const GAME := preload("res://Main.tscn")
const HERO := preload("res://hero_classes.gd")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    for choice in 3:
        var actor: Node3D = ACTOR.new()
        actor.configure(500+choice,false,choice)
        root.add_child(actor)
        for gear in ["unarmed","spear","bow","shield"]:
            actor.set_combat_equipped(gear)
            actor.melee_attack()
            var expected: String = {"unarmed":"Unarmed_Melee_Attack_Punch_A",
                "spear":"2H_Melee_Attack_Stab","bow":"2H_Ranged_Shoot","shield":"Block_Hit"}[gear]
            if actor.current_clip != expected or actor.animator.get_animation(expected).loop_mode != Animation.LOOP_NONE:
                _fail("incorrect attack animation for %s class %d" % [gear,choice]); return
            if actor.emote_until_msec-Time.get_ticks_msec() > 650:
                _fail("attack animation delays beyond server cooldown"); return
            actor.emote_until_msec=0
            actor._process(0.02)
            if actor.current_clip != "Idle":
                _fail("action animation does not return to Idle"); return
        actor.set_combat_equipped("shield")
        actor.shield_block()
        if actor.current_clip != "Block_Hit" or not actor.combat_visual.has_meta("blocking"):
            _fail("real shield blocking animation missing"); return
        actor.set_combat_equipped("unarmed")
        actor.hit_reaction()
        if actor.current_clip != "Hit_A":
            _fail("real hit reaction missing"); return
        actor.hero_ability_animation("heal")
        if actor.current_clip != "Spellcast_Shoot":
            _fail("real Mage animation missing"); return
        actor.hero_ability_animation("dash")
        if actor.current_clip != "Dodge_Forward":
            _fail("real Rogue animation missing"); return
        actor.queue_free()
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game.selected_avatar = HERO.ROGUE
    game._host()
    game.set_physics_process(false)
    var id: int = game.own_id
    var world: Node3D = game.get_node("Eldoria_Forest")
    game.players[id].position=Vector3(0,world.height_at(0,0)+1,0)
    game.wolf_alive=true
    game.wolf_position=game.players[id].position+Vector3(2,0,0)
    game.player_health[id]=100
    game.player_inventories[id] = game._empty_inventory()
    var player = game.players[id]
    var old_clip: String = player.current_clip
    if game._hero_ability_on_server(id,Vector3.ZERO):
        _fail("invalid dash accepted");return
    if player.current_clip != old_clip:
        _fail("refused dash played animation");return
    if not game._hero_ability_on_server(id,Vector3.RIGHT):
        _fail("valid dash refused");return
    if player.current_clip != "Dodge_Forward":
        _fail("validated dash animation not replicated locally");return
    game.hero_ability_visual(id,"invalid")
    if player.current_clip != "Dodge_Forward":
        _fail("invalid visual kind altered animation");return
    game.player_health[id]=100
    game._damage_player_on_server(id,10)
    if player.current_clip != "Hit_A":
        _fail("confirmed server damage does not play Hit_A");return
    print("TASK057 ANIMATIONS PASS 3 heroes, 4 weapon animations, shield, mage/rogue abilities, confirmed damage, rejection")
    quit(0)
func _fail(reason: String) -> void:
    printerr("TASK057 ANIMATIONS FAIL: "+reason)
    quit(1)
