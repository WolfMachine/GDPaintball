extends Node
class_name GameplayController

const Config = preload("res://config.gd")
const PlayerState = preload("res://state/PlayerState.gd")
const InputParser = preload("res://networking/InputParser.gd")
const MatchController = preload("res://MatchController.gd")
const SnapshotBuilder = preload("res://networking/SnapshotBuilder.gd")
const WorldGeometry = preload("res://world/WorldGeometry.gd")

signal match_should_end(winner_team)

var udp_server: Node
var match_controller: MatchController
var input_parser: InputParser
var snapshot_builder: SnapshotBuilder
var world_geometry: WorldGeometry

var player_registry: Node = null
var players: Dictionary = {}   # player_id -> PlayerState

func _ready():
	udp_server = get_node("../ENetServer")

	world_geometry = WorldGeometry.new()

	match_controller = MatchController.new()
	match_controller.world_geometry = world_geometry

	input_parser = InputParser.new()
	snapshot_builder = SnapshotBuilder.new()

	add_child(match_controller)
	add_child(input_parser)
	add_child(snapshot_builder)

	print("GameplayController initialized.")

func _resolve_registry_from_servermain():
	if player_registry != null:
		return

	var server_main := get_node("../ServerMain")
	if server_main != null and server_main.has_method("get_player_registry"):
		player_registry = server_main.get_player_registry()
		if player_registry != null:
			print("GameplayController: PlayerRegistry bound via ServerMain.")

# ---------------------------------------------------------
# MATCH LIFECYCLE
# ---------------------------------------------------------

func start_match(players_list: Array, teams: Dictionary):
	_resolve_registry_from_servermain()
	if player_registry == null:
		print("GameplayController: start_match called before PlayerRegistry exists.")
		return

	match_controller.reset()
	players.clear()

	for pid in players_list:
		var team := 0
		if teams.has(1) and teams[1].has(pid):
			team = 1
		_add_player(pid, team)

	match_controller.match_state = MatchController.MatchState.WAITING
	match_controller.time = 0.0

	print("GameplayController: Match setup complete with", players_list.size(), "players (WAITING).")

func begin_simulation():
	if match_controller.match_state == MatchController.MatchState.RUNNING:
		return

	match_controller.match_state = MatchController.MatchState.RUNNING
	print("GameplayController: Simulation BEGIN (RUNNING).")

func end_match():
	match_controller.match_state = MatchController.MatchState.ENDED
	print("GameplayController: Match ended.")

# ---------------------------------------------------------
# PLAYER MANAGEMENT
# ---------------------------------------------------------

func _add_player(player_id: String, team: int):
	var p := PlayerState.new()
	p.id = player_id
	p.team = team
	p.is_human = true

	p.health = Config.DEFAULT_HEALTH
	p.power = Config.DEFAULT_POWER
	p.collider_radius = Config.DEFAULT_COLLIDER_RADIUS
	p.speed = Config.DEFAULT_PLAYER_SPEED
	p.projectile_damage = Config.DEFAULT_PROJECTILE_DAMAGE

	match_controller.players.append(p)
	players[player_id] = p

	print("GameplayController: Added player", player_id, "to team", team)

func remove_player(player_id: String):
	match_controller.players = match_controller.players.filter(
		func(p): return p.id != player_id
	)
	players.erase(player_id)
	print("GameplayController: Removed player", player_id)

	var remaining_count := players.size()
	if remaining_count <= 1 and match_controller.match_state == MatchController.MatchState.RUNNING:
		var winner_team := -1
		if remaining_count == 1:
			for pid in players.keys():
				var ps: PlayerState = players[pid]
				if ps != null:
					winner_team = ps.team
					break
		end_match()
		emit_signal("match_should_end", winner_team)

func get_player_state(player_id: String) -> PlayerState:
	return players.get(player_id, null)

# ---------------------------------------------------------
# AUTHORITATIVE PLAYER SNAPSHOT FOR CLIENTS
# ---------------------------------------------------------

func get_player_state_table() -> Dictionary:
	var table := {}

	for pid in players.keys():
		var ps: PlayerState = players[pid]
		if ps == null:
			continue

		var username := ""
		if player_registry != null and player_registry.has_method("get_by_player_id"):
			var reg_ps = player_registry.get_by_player_id(pid)
			if reg_ps != null:
				username = reg_ps.username

		table[pid] = {
			"username": username,
			"team": ps.team,
			"position": [ps.position.x, ps.position.y],
			"heading": ps.heading
		}

	return table

# ---------------------------------------------------------
# INPUT + TICK
# ---------------------------------------------------------

func apply_input(player_id: String, data: Dictionary):
	input_parser.apply_input_to_player(player_id, data, match_controller.players)

func _process(delta: float):
	_resolve_registry_from_servermain()

	if match_controller.match_state != MatchController.MatchState.RUNNING:
		return

	var tick_delta = Config.TICK_DELTA

	while delta >= tick_delta:
		_process_tick(tick_delta)
		delta -= tick_delta

func _process_tick(delta: float):
	match_controller.tick(delta)
	_send_snapshot()

	var remaining_count := players.size()
	if remaining_count <= 1 and match_controller.match_state == MatchController.MatchState.RUNNING:
		var winner_team := -1
		if remaining_count == 1:
			for pid in players.keys():
				var ps: PlayerState = players[pid]
				if ps != null:
					winner_team = ps.team
					break
		end_match()
		emit_signal("match_should_end", winner_team)

func _send_snapshot():
	var snapshot := snapshot_builder.build_snapshot(
		match_controller.players,
		match_controller.match_state,
		match_controller.time
	)

	udp_server.broadcast_snapshot(snapshot)
