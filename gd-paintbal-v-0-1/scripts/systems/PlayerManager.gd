extends Node
class_name PlayerManager

@export var player_scene: PackedScene

var players: Dictionary = {}          # pid -> Player node
var local_player_id: String = ""      # UUID string

var full_state: Dictionary = {}       # pid -> authoritative state dict

# ---------------------------------------------------------
# SPAWN FROM SNAPSHOT (UPDATED)
# ---------------------------------------------------------

func spawn_from_snapshot(players_table: Dictionary, local_id: String) -> void:
	# 🔥 NEW: store local ID BEFORE spawning
	local_player_id = local_id

	print("SPAWN_FROM_SNAPSHOT: received", players_table.size(), "players")

	for pid in players_table.keys():
		var p = players_table[pid]

		var username = p.get("username", "")
		var team = p.get("team", 0)
		var pos = Vector2(p.position[0], p.position[1])
		var heading = p.get("heading", 0.0)

		var is_local = (pid == local_player_id)

		if players.has(pid):
			print("SPAWN_FROM_SNAPSHOT: already exists:", pid)
			continue

		print("SPAWN_FROM_SNAPSHOT: spawning", pid)
		spawn_player(pid, is_local, username, team, pos, heading)

# ---------------------------------------------------------
# SPAWN PLAYER
# ---------------------------------------------------------

func spawn_player(player_id: String, is_local: bool, username: String, team: int, position: Vector2, heading: float) -> void:
	print("SPAWN_PLAYER called:", player_id, "is_local=", is_local, "pos=", position, "heading=", heading)

	if players.has(player_id):
		print("SPAWN_PLAYER: already exists:", player_id)
		return

	var p = player_scene.instantiate()

	# Populate state
	p.state.player_id = player_id
	p.state.is_local = is_local
	p.state.username = username
	p.state.team = team
	p.state.position = position
	p.state.heading = heading
	p.state.velocity = Vector2.ZERO
	p.state.health = 100
	p.state.alive = true
	p.state.fire_request = false

	p.global_position = position

	# 🔥 NEW: ensure local ID is stored
	if is_local:
		local_player_id = player_id

	players[player_id] = p
	add_child(p)

	full_state[player_id] = {
		"id": player_id,
		"t": team,
		"x": position.x,
		"y": position.y,
		"vx": 0.0,
		"vy": 0.0,
		"h": heading,
		"hp": 100,
		"a": 1,
		"f": 0
	}

	print("SPAWN_PLAYER: instanced node:", p.name, "global_position=", p.global_position, "visible=", p.visible)
	print("SPAWN_PLAYER: players keys =", players.keys())

# ---------------------------------------------------------
# REMOVE PLAYER
# ---------------------------------------------------------

func remove_player(player_id: String) -> void:
	if not players.has(player_id):
		return

	players[player_id].queue_free()
	players.erase(player_id)
	full_state.erase(player_id)

# ---------------------------------------------------------
# APPLY SNAPSHOT (UDP)
# ---------------------------------------------------------

func apply_snapshot(snapshot: Dictionary) -> void:
	if not snapshot.has("p"):
		return

	var deltas: Array = snapshot["p"]

	for d in deltas:
		var pid: String = d["id"]

		if not players.has(pid):
			print("APPLY_SNAPSHOT: no local node for", pid)
			continue

		var p = players[pid]

		if p.state.is_local:
			# Local player ignores authoritative movement
			continue

		print("APPLY_SNAPSHOT: updating", pid, "delta=", d)

		if not full_state.has(pid):
			full_state[pid] = {}

		var state: Dictionary = full_state[pid]

		for key in d.keys():
			state[key] = d[key]

		_apply_to_player_node(p, state)

# ---------------------------------------------------------
# APPLY STATE TO NODE
# ---------------------------------------------------------

func _apply_to_player_node(p, state: Dictionary) -> void:
	if state.has("x"):
		p.state.position.x = state["x"]
	if state.has("y"):
		p.state.position.y = state["y"]

	if state.has("vx"):
		p.state.velocity.x = state["vx"]
	if state.has("vy"):
		p.state.velocity.y = state["vy"]

	if state.has("h"):
		p.state.heading = state["h"]

	if state.has("hp"):
		p.state.health = state["hp"]

	if state.has("a"):
		p.state.alive = state["a"] == 1
		if not p.state.alive:
			remove_player(p.state.player_id)
			return

	if state.has("f") and state["f"] == 1:
		p.state.fire_request = true

	print("_apply_to_player_node: applied to", p.state.player_id, "pos=", p.state.position, "heading=", p.state.heading)

# ---------------------------------------------------------
# PROCESS LOOP
# ---------------------------------------------------------

func _process(_delta: float) -> void:
	for pid in players:
		var p = players[pid]

		if p.state.is_local:
			continue

		p.global_position = p.state.position
		p.rotation = p.state.heading

# ---------------------------------------------------------
# DEBUG
# ---------------------------------------------------------

func debug_list_players() -> void:
	print("DEBUG: players count =", players.size())
	for pid in players.keys():
		var n = players[pid]
		print("  ", pid, "->", n.name, "pos=", n.global_position, "is_local=", n.state.is_local, "visible=", n.visible)
