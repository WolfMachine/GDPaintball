extends Node
class_name SnapshotBuilder

var last_state: Dictionary = {}   # Dictionary<String, Dictionary>

func build_snapshot(players: Array, match_state: int, time: float) -> Dictionary:
	var deltas: Array = []

	for p in players:
		var pid: String = p.id

		var cur: Dictionary = {
			"id": pid,
			"t": p.team,
			"x": p.position.x,
			"y": p.position.y,
			"vx": p.velocity.x,
			"vy": p.velocity.y,
			"h": p.heading,
			"hp": p.health,
			"a": int(p.is_alive()),
			"f": int(p.fire_request)
		}

		var prev: Dictionary = last_state.get(pid, {})

		var delta: Dictionary = _compute_delta(pid, cur, prev)

		if delta.size() > 1:
			deltas.append(delta)

		last_state[pid] = cur

	return {
		"t": time,
		"s": match_state,
		"p": deltas
	}

func _compute_delta(pid: String, cur: Dictionary, prev: Dictionary) -> Dictionary:
	var d: Dictionary = { "id": pid }

	for key in cur.keys():
		if key == "id":
			continue
		if not prev.has(key) or prev[key] != cur[key]:
			d[key] = cur[key]

	return d
