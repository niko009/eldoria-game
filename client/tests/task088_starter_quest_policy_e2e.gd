extends SceneTree
const Q := preload("res://quest_progress.gd")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var empty: Dictionary = Q.initial()
    if not Q.valid(empty) or not Q.valid({}) or Q.can_claim(empty,{}, {},0):
        _fail("invalid initial state");return
    if Q.valid({Q.ID:{"status":"claimed","wood":0,"stone":0}}):
        _fail("fraudulent claim state valid");return
    if Q.valid({Q.ID:{"status":"active","wood":5,"stone":2}}):
        _fail("overflow valid");return
    var first := Q.gather(empty,"wood",2)
    if int(first[Q.ID]["wood"]) != 2 or int(empty[Q.ID]["wood"]) != 0:
        _fail("in-place mutation or wrong count");return
    first = Q.gather(first,"wood",2)
    first = Q.gather(first,"stone",2)
    if str(first[Q.ID]["status"]) != "completed" or int(first[Q.ID]["wood"]) != 3:
        _fail("completion threshold");return
    var inventory := {"herb":999999}
    var skills := {"defense":0}
    if Q.can_claim(first,inventory,skills,0):
        _fail("reward over capacity");return
    inventory["herb"] = 7
    if not Q.can_claim(first,inventory,skills,0) or not Q.can_claim(first,inventory,{"magic":0},2):
        _fail("legitimate class award refused");return
    first[Q.ID]["status"] = "claimed"
    if Q.can_claim(first,inventory,skills,0) or Q.gather(first,"stone",99) != first:
        _fail("repeated claim or future progress");return
    print("TASK088 POLICY PASS bounded progress, completion, overflow, class XP, no replay")
    quit(0)
func _fail(message: String) -> void:
    printerr("TASK088 POLICY FAIL: "+message);quit(1)
