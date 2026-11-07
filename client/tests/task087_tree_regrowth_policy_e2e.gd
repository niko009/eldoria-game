extends SceneTree
const POLICY := preload("res://tree_regrowth.gd")
func _initialize() -> void:
    var started := 1790000000
    var deadline: int = POLICY.deadline_on_depletion(started)
    if deadline != started + 300 or POLICY.ready(deadline, started + 299) or not POLICY.ready(deadline, started + 300):
        _fail("deadline 299/300 boundary")
        return
    if not POLICY.ready(deadline, started + 900) or POLICY.ready(0, started + 900):
        _fail("expired/legacy missing deadline")
        return
    var radii := {"campfire": 1.5, "tent": 2.5}
    var buildings := {1:{"kind":"campfire","x":2.0,"z":0.0}}
    if not POLICY.blocked_by_building(Vector3(2.0,0,0),buildings,radii):
        _fail("overlapping building was not detected")
        return
    if POLICY.blocked_by_building(Vector3(10.0,0,0),buildings,radii):
        _fail("distant building blocks regrowth")
        return
    print("TASK087 TREE REGROWTH POLICY PASS: persistent deadline, 299/300, building clearance")
    quit(0)
func _fail(reason: String) -> void:
    printerr("TASK087 TREE REGROWTH POLICY FAIL: " + reason)
    quit(1)
