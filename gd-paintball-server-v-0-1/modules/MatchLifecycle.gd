extends Node
class_name MatchLifecycle

signal match_started(players, teams)
signal match_ended(winner_team)
signal player_joined_match(player_id, team)
signal player_left_match(player_id)

var active_players: Array = []
var active_teams := {}
var match_running := false

func start_match(players: Array, teams: Dictionary) -> void:
	active_players = players.duplicate()
	active_teams = teams.duplicate()
	match_running = true
	emit_signal("match_started", active_players, active_teams)

func end_match(winner_team: int) -> void:
	if not match_running:
		return

	match_running = false

	# IMPORTANT: Do NOT reset yet.
	# Orchestrator needs active_players intact to send match_end packets.
	emit_signal("match_ended", winner_team)

	# Orchestrator will call reset() AFTER it finishes cleanup.

func reset() -> void:
	active_players.clear()
	active_teams.clear()
	match_running = false

func handle_player_joined(player_id: String, team: int) -> void:
	if not active_players.has(player_id):
		active_players.append(player_id)
		emit_signal("player_joined_match", player_id, team)

func handle_player_left(player_id: String) -> void:
	if active_players.has(player_id):
		active_players.erase(player_id)
		emit_signal("player_left_match", player_id)

func handle_player_disconnected(player_id: String) -> void:
	handle_player_left(player_id)

# Optional helper for clarity
func remove_player(player_id: String) -> void:
	handle_player_left(player_id)
