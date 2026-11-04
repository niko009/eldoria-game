extends RefCounted
## Deterministic server-only passive wildlife behavior and combat metadata.
const SPAWNS := [
	{"species":"rabbit","x":-6.0,"z":-8.0,"hp":24},
	{"species":"rabbit","x":9.0,"z":-7.0,"hp":24},
	{"species":"deer","x":-9.0,"z":10.0,"hp":55},
	{"species":"deer","x":12.0,"z":10.0,"hp":55},
	{"species":"dummy","x":-3.0,"z":-4.5,"hp":100},
	{"species":"dummy","x":3.0,"z":-4.5,"hp":100},
	{"species":"rabbit","x":-16.0,"z":-13.0,"hp":24},
	{"species":"rabbit","x":16.0,"z":-12.0,"hp":24},
	{"species":"rabbit","x":-20.0,"z":5.0,"hp":24},
	{"species":"rabbit","x":22.0,"z":6.0,"hp":24},
	{"species":"deer","x":-22.0,"z":16.0,"hp":55},
	{"species":"deer","x":24.0,"z":18.0,"hp":55},
	{"species":"deer","x":-15.0,"z":25.0,"hp":55},
	{"species":"deer","x":18.0,"z":-22.0,"hp":55}
]
const RESPAWN_MS := 20000
const HIT_XP := 2
const DEFEAT_XP := 5

static func construct(world: Node3D) -> Dictionary:
	var result := {}
	for index in SPAWNS.size():
		var config: Dictionary = SPAWNS[index]
		var home := Vector3(float(config["x"]),0.0,float(config["z"]))
		# New wildlife must not spawn inside procedural trees or rocks.
		if world.collides_at(Vector2(home.x,home.z),0.32):
			for attempt in 32:
				var angle := float(attempt)*2.39996323
				var radius := 1.5 + float(attempt/8)*1.7
				var candidate := Vector2(home.x+cos(angle)*radius,home.z+sin(angle)*radius)
				if not world.collides_at(candidate,0.32):
					home.x = candidate.x
					home.z = candidate.y
					break
		home.y = world.height_at(home.x,home.z)+0.1
		result[index+1] = {"species":config["species"],"home":home,"position":home,
			"hp":int(config["hp"]),"max_hp":int(config["hp"]),"alive":true,
			"direction":Vector3.ZERO,"respawn_at":0}
	return result

static func tick(mobs: Dictionary, players: Dictionary, health: Dictionary, world: Node3D, delta: float, now: int) -> bool:
	var changed := false
	for mob_id in mobs:
		var critter: Dictionary = mobs[mob_id]
		if critter["species"] == "dummy":
			continue
		if not critter["alive"]:
			if now >= int(critter["respawn_at"]):
				critter["alive"] = true
				critter["hp"] = critter["max_hp"]
				critter["position"] = critter["home"]
				critter["direction"] = Vector3.ZERO
				changed = true
			continue
		var at: Vector3 = critter["position"]
		var near_dist_sq := 36.0 if critter["species"] == "rabbit" else 49.0
		var closest := Vector3.ZERO
		var has_threat := false
		for player_id in players:
			if int(health.get(player_id,0)) <= 0:
				continue
			var location: Vector3 = players[player_id].position
			var distance_sq := Vector2(at.x-location.x,at.z-location.z).length_squared()
			if distance_sq < near_dist_sq:
				has_threat = true
				closest = location
				near_dist_sq = distance_sq
		var direction := Vector3.ZERO
		var speed := 0.0
		if has_threat:
			direction = Vector3(at.x-closest.x,0,at.z-closest.z).normalized()
			speed = 3.0 if critter["species"] == "rabbit" else 4.0
		elif at.distance_to(critter["home"]) > 8.0:
			direction = (critter["home"]-at).normalized()
			speed = 1.6
		else:
			# Short walks alternating with grazing, staggered between animals.
			var cycle := fposmod(float(now)*0.001 + float(mob_id)*3.7,17.0)
			if cycle >= 10.0:
				critter["direction"] = Vector3.ZERO
				continue
			var phase: float = floorf(float(now)*0.001/17.0)*1.7 + float(mob_id)*2.1
			direction = Vector3(sin(phase),0,cos(phase))
			speed = 0.45 if critter["species"] == "deer" else 0.65
		if direction.length_squared() < 0.001:
			continue
		var moved: Vector3 = world.move_actor(at,direction*speed*delta,0.32)
		moved.y = world.height_at(moved.x,moved.z)+0.1
		critter["position"] = moved
		critter["direction"] = (moved-at).normalized() if moved.distance_squared_to(at) > 0.000001 else Vector3.ZERO
	return changed
