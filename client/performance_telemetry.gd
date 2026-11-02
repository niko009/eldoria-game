extends Node
# Low-rate performance aggregates. No token, IP, device model or player name.
const INTERVAL_MS := 60000
const MAX_FRAME_SAMPLES := 7200
var enabled := true
var capture: Array[float] = []
var started_msec := 0
var elapsed_seconds := 0.0
var frame_count := 0
var last_rtt_ms := 0
var last_report: Dictionary = {}

func _ready() -> void:
    started_msec = Time.get_ticks_msec()

func sample_frame(delta: float) -> void:
    if not enabled or delta <= 0.0:
        return
    elapsed_seconds += delta
    frame_count += 1
    if capture.size() < MAX_FRAME_SAMPLES:
        capture.append(clampf(delta*1000.0,0.01,1000.0))

func ready_to_report() -> bool:
    return enabled and started_msec > 0 and Time.get_ticks_msec()-started_msec >= INTERVAL_MS and capture.size() >= 60

func make_report(quality: int, version: String) -> Dictionary:
    if not enabled or capture.size() < 2 or elapsed_seconds <= 0.0:
        return {}
    var values := capture.duplicate()
    values.sort()
    var avg_fps := float(frame_count) / elapsed_seconds
    var low_fps := 1000.0 / maxf(0.1,float(values[maxi(0,int(ceilf(values.size()*0.95))-1)]))
    var report := {
        "version":version,
        "platform":"android" if OS.get_name()=="Android" else ("windows" if OS.get_name()=="Windows" else "test"),
        "quality":"low" if quality==0 else "high",
        "fps_avg":snappedf(avg_fps,0.1),
        "fps_low_5":snappedf(low_fps,0.1),
        "frame_p95_ms":snappedf(float(values[maxi(0,int(ceilf(values.size()*0.95))-1)]),0.1),
        "memory_mb":clampi(roundi(float(OS.get_static_memory_usage()) / (1024.0*1024.0)),1,65536),
        "rtt_ms":clampi(last_rtt_ms,0,10000),
        "samples":capture.size()
    }
    last_report = report.duplicate()
    capture.clear()
    elapsed_seconds = 0.0
    frame_count = 0
    started_msec = Time.get_ticks_msec()
    return report

func set_enabled(value: bool) -> void:
    enabled = value
    capture.clear()
    elapsed_seconds = 0.0
    started_msec = Time.get_ticks_msec()
