extends RefCounted
## Server-only cooperative camp cycle. Time is monotonic milliseconds supplied
## by the caller, keeping logic deterministic and easy to test offline.
class_name EldoriaCampRaid

const PREPARATION_MS := 90000
const NIGHT_MS := 140000
const INTERMISSION_MS := 8000
const WOLVES_PER_NIGHT := 4

var phase := "prepare"
var deadline_ms := 0
var round := 1
var kills := 0
var resolved := false

func begin(now_ms: int) -> void:
	phase = "prepare"
	deadline_ms = now_ms + PREPARATION_MS
	round = 1
	kills = 0
	resolved = false

func advance(now_ms: int) -> String:
	if deadline_ms <= 0:
		begin(now_ms)
		return ""
	if now_ms < deadline_ms:
		return ""
	match phase:
		"prepare":
			phase = "night"
			deadline_ms = now_ms + NIGHT_MS
			kills = 0
			resolved = false
			return "night_started"
		"night":
			phase = "intermission"
			deadline_ms = now_ms + INTERMISSION_MS
			resolved = true
			return "night_failed"
		"intermission":
			phase = "prepare"
			deadline_ms = now_ms + PREPARATION_MS
			round += 1
			kills = 0
			resolved = false
			return "prepare_started"
	return ""

func wolf_defeated(now_ms: int) -> String:
	if phase != "night" or resolved:
		return ""
	kills += 1
	if kills >= WOLVES_PER_NIGHT:
		phase = "intermission"
		deadline_ms = now_ms + INTERMISSION_MS
		resolved = true
		return "night_won"
	return "wolf_defeated"

func remaining_seconds(now_ms: int) -> int:
	return maxi(0, ceili(float(deadline_ms - now_ms) / 1000.0))

func snapshot(now_ms: int) -> Dictionary:
	return {"phase": phase, "round": round, "kills": kills,
		"goal": WOLVES_PER_NIGHT, "seconds": remaining_seconds(now_ms)}
