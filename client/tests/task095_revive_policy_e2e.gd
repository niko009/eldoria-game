extends SceneTree

const POLICY := preload("res://coop_revive_policy.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var a := Vector3.ZERO
    var b := Vector3(2,0,0)
    if not POLICY.eligible(2,3,1000,13000,60,0,a,b,true,false):
        _fail("valid teammate rescue rejected")
        return
    if POLICY.eligible(2,2,1000,13000,60,0,a,b,true,false):
        _fail("self revive accepted")
        return
    if POLICY.eligible(2,3,13000,13000,60,0,a,b,true,false):
        _fail("expired window accepted")
        return
    if POLICY.eligible(2,3,1000,13000,60,0,a,Vector3(3,0,0),true,false):
        _fail("out-of-range revive accepted")
        return
    if POLICY.eligible(2,3,1000,13000,60,0,a,b,false,false):
        _fail("revive through wall accepted")
        return
    if POLICY.eligible(2,3,1000,13000,60,0,a,b,true,true):
        _fail("interrupted revive accepted")
        return
    if POLICY.eligible(2,3,1000,13000,0,0,a,b,true,false):
        _fail("dead reviver accepted")
        return
    if POLICY.eligible(2,3,1000,13000,60,10,a,b,true,false):
        _fail("living target accepted")
        return
    if POLICY.hold_complete(1000,2799,-1) or not POLICY.hold_complete(1000,2800,-1):
        _fail("hold duration boundary incorrect")
        return
    if POLICY.hold_complete(1000,3000,1200):
        _fail("interrupted hold completed")
        return
    print("TASK095 REVIVE POLICY PASS eligibility, distance, LOS, expiry, interruption, hold")
    quit(0)

func _fail(reason: String) -> void:
    printerr("TASK095 REVIVE POLICY FAIL: "+reason)
    quit(1)