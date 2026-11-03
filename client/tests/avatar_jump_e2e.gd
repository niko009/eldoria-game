extends SceneTree
# Executed by tests/run_avatar_jump_e2e.sh in two independent processes.
const SCENE := preload("res://Main.tscn")
const MODELS := preload("res://avatar_profile.gd")
const JUMP := preload("res://jump_motion.gd")
var game: Node3D

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var role := "A" if OS.get_cmdline_user_args().has("--a") else "B"
    game = SCENE.instantiate()
    root.add_child(game)
    await process_frame
    # Hero class is chosen before connecting. In-world class switches require a campfire.
    var choice: int = 1 if role == "A" else 2
    var other_choice: int = 2 if role == "A" else 1
    game._choose_avatar(choice)
    game._join()
    if not await _await_connected(480):
        _fail(role+" could not join two-player world")
        return
    var me: int = game.own_id
    var other := _other(me)
    if not await _await_choices(me,other,choice,other_choice,300):
        _fail(role + " remote avatar selection not replicated")
        return
    if game.players[me].model_kind != MODELS.NAMES[choice] or game.players[other].model_kind != MODELS.NAMES[other_choice]:
        _fail(role + " wrong visual variant")
        return
    print("AVATAR SYNC PASS "+role+" mine="+game.players[me].model_kind+" remote="+game.players[other].model_kind)
    var world: Node3D = game.get_node("Eldoria_Forest")
    var feet: Vector3 = game.players[other].position
    var ground: float = world.height_at(feet.x,feet.z)+1.0
    if role == "B":
        for i in range(32):
            await process_frame
        game._try_jump()
        var peak := -999.0
        var airborne_seen := false
        for i in range(270):
            await process_frame
            var p: Vector3 = game.players[me].position
            peak = maxf(peak,p.y-world.height_at(p.x,p.z)-1.0)
            if game.players[me].airborne:
                airborne_seen = true
        if peak < 0.45 or not airborne_seen:
            _fail("jump did not lift local avatar (peak=%.2f)" % peak)
            return
        if absf(game.players[me].position.y-world.height_at(game.players[me].position.x,game.players[me].position.z)-1.0)>0.15:
            _fail("jump did not land")
            return
        print("JUMP LOCAL PASS B peak=%.2f" % peak)
        game._disconnect()
        quit(0)
    else:
        var peak := -999.0
        var saw_animation := false
        for i in range(380):
            await process_frame
            if game.players.has(other):
                var p: Vector3 = game.players[other].position
                peak = maxf(peak,p.y-ground)
                if game.players[other].airborne:
                    saw_animation = true
        if peak < 0.35 or not saw_animation:
            _fail("remote jump did not replicate (peak=%.2f animated=%s)" % [peak,saw_animation])
            return
        print("JUMP REMOTE PASS A peak=%.2f" % peak)
        if not await _await_disconnected(350):
            _fail("B disconnect was not observed")
            return
        quit(0)

func _await_connected(frames: int) -> bool:
    for i in range(frames):
        if game.own_id != 0 and game.players.size()==2:
            return true
        await process_frame
    return false

func _await_choices(me: int, other: int, mine: int, remote: int, frames: int) -> bool:
    for i in range(frames):
        if int(game.player_choices.get(me,-1)) == mine and int(game.player_choices.get(other,-1)) == remote:
            return true
        await process_frame
    return false

func _await_disconnected(frames: int) -> bool:
    for i in range(frames):
        if game.players.size() == 1:
            return true
        await process_frame
    return false

func _other(me: int) -> int:
    for id in game.players.keys():
        if id != me:
            return id
    return -1

func _fail(s: String) -> void:
    printerr("AVATAR/JUMP FAIL: "+s)
    quit(1)
