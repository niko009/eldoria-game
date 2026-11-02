extends SceneTree
const PERF := preload("res://performance_telemetry.gd")
const GAME := preload("res://Main.tscn")
func _initialize() -> void:
    call_deferred("_test")
func _test() -> void:
    var probe: Node = PERF.new()
    root.add_child(probe)
    for i in range(120):
        probe.sample_frame(1.0/60.0 if i<110 else 0.125)
    var rep: Dictionary = probe.make_report(0,"0.5.1")
    if rep.size()!=9 or rep["samples"]!=120 or rep["fps_avg"]>=60 or rep["frame_p95_ms"]<100 or rep["quality"]!="low":
        _fail("incorrect FPS/p95 or schema: "+str(rep))
        return
    probe.set_enabled(false)
    for i in range(100):
        probe.sample_frame(0.01)
    if not probe.make_report(1,"0.5.1").is_empty():
        _fail("opted-out client generated telemetry")
        return
    var game: Node3D = GAME.instantiate()
    root.add_child(game)
    await process_frame
    game._host()
    if game.telemetry_sink != null:
        _fail("Godot test world unexpectedly contacts a live analytics sink")
        return
    if not game.telemetry.enabled:
        # Test preferences may survive prior test runs. Enable for deterministic test.
        game.telemetry.set_enabled(true)
    game.telemetry.last_rtt_ms=42
    for i in range(120):
        game.telemetry.sample_frame(0.0167)
    game._submit_telemetry()
    if game.telemetry.last_report.size()!=9:
        _fail("client didn't build a valid report when connected")
        return
    if game.telemetry.last_report.has("identity") or game.telemetry.last_report.has("token") or game.telemetry.last_report.has("ip"):
        _fail("private data leaked to diagnostics report")
        return
    print("TELEMETRY CLIENT PASS p95/avg FPS, schema, opt-out, private-data exclusions, no prod sink")
    game._disconnect()
    quit(0)
func _fail(message:String)->void:
    printerr("TELEMETRY CLIENT FAIL: "+message)
    quit(1)
