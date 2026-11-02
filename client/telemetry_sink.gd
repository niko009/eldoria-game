extends Node
# Server-only, bounded async bridge to localhost .NET persistence telemetry API.
const MAX_QUEUE := 10
var endpoint := ""
var api_key := ""
var request: HTTPRequest
var queue: Array[Dictionary] = []
var in_flight := false
var sent := 0
var failures := 0
var rejected := 0

func _ready() -> void:
    request = HTTPRequest.new()
    request.timeout = 4.0
    request.body_size_limit = 8192
    add_child(request)
    request.request_completed.connect(_finished)

func configure(url: String, secret: String) -> bool:
    if not url.begins_with("http://127.0.0.1:") or secret.length() < 24:
        return false
    endpoint = url.trim_suffix("/") + "/v1/telemetry"
    api_key = secret
    return true

func enqueue(report: Dictionary) -> bool:
    if endpoint.is_empty() or queue.size() >= MAX_QUEUE:
        return false
    queue.append(report.duplicate(true))
    _drain()
    return true

func _drain() -> void:
    if in_flight or queue.is_empty() or endpoint.is_empty():
        return
    var data: Dictionary = queue.pop_front()
    in_flight = true
    var error := request.request(endpoint,[
        "X-Eldoria-Server-Key: "+api_key,
        "Content-Type: application/json"
    ],HTTPClient.METHOD_POST,JSON.stringify(data))
    if error != OK:
        failures += 1
        in_flight = false
        call_deferred("_drain")

func _finished(result: int, http_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
    in_flight = false
    if result == HTTPRequest.RESULT_SUCCESS and http_code == 202:
        sent += 1
    else:
        failures += 1
    _drain()

func pending() -> int:
    return queue.size() + (1 if in_flight else 0)
