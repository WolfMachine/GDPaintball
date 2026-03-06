extends Node
class_name MatchOrchestrator

var match_lifecycle
var match_scheduler
var team_assigner
var queue_manager
var registry
var admin_module
var session_manager
var udp_server
var gameplay

var ready_players := {}          # player_id -> bool
var countdown_seconds := 3
var countdown_timer: Timer

func initialize(
	_match_lifecycle,
	_match_scheduler,
	_team_assigner,
	_queue_manager,
	_registry,
	_admin_module,
	_session_manager,
	_udp_server,
	_gameplay
):
	match_lifecycle = _match_lifecycle
	match_scheduler = _match_scheduler
	team_assigner = _team_assigner
	queue_manager = _queue_manager
	registry = _registry
	admin_module = _admin_module
	session_manager = _session_manager
	udp_server = _udp_server
	gameplay = _gameplay

	# Lifecycle signals
	match_lifecycle.connect("match_started", Callable(self, "_on_match_started"))
	match_lifecycle.connect("match_ended", Callable(self, "_on_match_ended"))
	match_lifecycle.connect("player_joined_match", Callable(self, "_on_player_joined_match"))
	match_lifecycle.connect("player_left_match", Callable(self, "_on_player_left_match"))

	# Gameplay → Orchestrator (critical)
	gameplay.connect("match_should_end", Callable(self, "_on_gameplay_match_end"))

	# Countdown timer
	countdown_timer = Timer.new()
	countdown_timer.one_shot = true
	add_child(countdown_timer)
	countdown_timer.timeout.connect(Callable(self, "_on_countdown_finished"))

# ---------------------------------------------------------
# PUBLIC: CALLED BY UDP SERVER ON DISCONNECT
# ---------------------------------------------------------

func handle_udp_disconnect(player_id: String):
	if match_lifecycle.match_running and match_lifecycle.active_players.has(player_id):
		match_lifecycle.handle_player_left(player_id)
	session_manager.handle_disconnect(player_id)

# ---------------------------------------------------------
# MATCH SCHEDULING
# ---------------------------------------------------------

func process(delta):
	if match_scheduler.should_run(delta):
		_attempt_start_match()

func _attempt_start_match():
	if match_lifecycle.match_running:
		return
	if not queue_manager.has_enough_players(2):
		return

	var selected = queue_manager.pop_players(16)
	var teams = team_assigner.assign_teams(selected)
	match_lifecycle.start_match(selected, teams)

# ---------------------------------------------------------
# MATCH START (SERVER SPAWNS, CLIENTS PREPARE)
# ---------------------------------------------------------

func _on_match_started(players_list, teams):
	ready_players.clear()

	if udp_server and udp_server.has_method("start_listening"):
		udp_server.start_listening(udp_server.port)

	for player_id in players_list:
		var ps = registry.get_by_player_id(player_id)
		if ps == null:
			continue

		if udp_server and udp_server.has_method("register_player_token"):
			udp_server.register_player_token(player_id, ps.auth_token)

		var udp_port = udp_server.port if udp_server != null else 0
		var team := 0
		if teams.has(1) and teams[1].has(player_id):
			team = 1

		var msg = {
			"type": "match_start",
			"player_id": player_id,
			"username": ps.username,
			"team": team,
			"udp_port": udp_port,
			"auth_token": ps.auth_token
		}

		if admin_module:
			admin_module._sniff_packet("out", player_id, msg, "tcp")

		session_manager.send_tcp(player_id, msg)

	if gameplay:
		gameplay.start_match(players_list, teams)

# ---------------------------------------------------------
# MATCH END
# ---------------------------------------------------------

func _on_match_ended(winner_team):
	var returning = match_lifecycle.active_players.duplicate()
	queue_manager.return_players(returning)

	if gameplay:
		gameplay.end_match()

	for player_id in returning:
		if admin_module:
			admin_module._sniff_packet("out", player_id, {
				"type": "match_end",
				"winner": winner_team
			}, "tcp")

		session_manager.send_tcp(player_id, {
			"type": "match_end",
			"winner": winner_team
		})

	if udp_server and udp_server.has_method("stop_listening"):
		udp_server.stop_listening()

# ---------------------------------------------------------
# GAMEPLAY → LIFECYCLE BRIDGE
# ---------------------------------------------------------

func _on_gameplay_match_end(winner_team):
	# Forward to lifecycle so the match ends cleanly
	match_lifecycle.end_match(winner_team)

# ---------------------------------------------------------
# PLAYER JOIN / LEAVE EVENTS (DYNAMIC DURING PRE/POST)
# ---------------------------------------------------------

func _on_player_joined_match(player_id: String, team: int):
	var ps = registry.get_by_player_id(player_id)
	var username = "" if ps == null else ps.username

	for other in match_lifecycle.active_players:
		var msg = {
			"type": "player_joined",
			"player_id": player_id,
			"username": username,
			"team": team,
			"position": [0, 0],
			"heading": 0.0
		}

		if admin_module:
			admin_module._sniff_packet("out", other, msg, "tcp")

		session_manager.send_tcp(other, msg)

	# Give the joining player the full roster
	_send_players_snapshot_to(player_id)

func _on_player_left_match(player_id: String):
	for other in match_lifecycle.active_players:
		if other == player_id:
			continue

		var msg = {"type": "player_left", "player_id": player_id}

		if admin_module:
			admin_module._sniff_packet("out", other, msg, "tcp")

		session_manager.send_tcp(other, msg)

# ---------------------------------------------------------
# GAMEPLAY INPUT
# ---------------------------------------------------------

func apply_input(player_id: String, input_data):
	if gameplay:
		gameplay.apply_input(player_id, input_data)

# ---------------------------------------------------------
# PLAYER PACKET ROUTING (READY / SNAPSHOT / DISCONNECT)
# ---------------------------------------------------------

func handle_player_packet(player_id: String, data):
	if admin_module:
		admin_module._sniff_packet("in", player_id, data, "tcp")

	match data.type:
		"disconnect":
			var ps = registry.get_by_player_id(player_id)
			if ps:
				session_manager.handle_disconnect(player_id)

		"request_players":
			_send_players_snapshot_to(player_id)

		"ready":
			_mark_player_ready(player_id)

# ---------------------------------------------------------
# SNAPSHOT + READY HELPERS
# ---------------------------------------------------------

func _send_players_snapshot_to(player_id: String):
	if gameplay == null:
		return

	var snapshot = gameplay.get_player_state_table()
	var msg = {
		"type": "players_snapshot",
		"players": snapshot
	}

	if admin_module:
		admin_module._sniff_packet("out", player_id, msg, "tcp")

	session_manager.send_tcp(player_id, msg)

func _mark_player_ready(player_id: String):
	ready_players[player_id] = true
	if _all_players_ready():
		_start_countdown()

func _all_players_ready() -> bool:
	for pid in match_lifecycle.active_players:
		if not ready_players.has(pid) or not ready_players[pid]:
			return false
	return true

func _start_countdown():
	for pid in match_lifecycle.active_players:
		var msg = {"type": "countdown", "value": countdown_seconds}
		if admin_module:
			admin_module._sniff_packet("out", pid, msg, "tcp")
		session_manager.send_tcp(pid, msg)

	countdown_timer.start(countdown_seconds)

func _on_countdown_finished():
	if gameplay:
		gameplay.begin_simulation()

	for pid in match_lifecycle.active_players:
		var msg = {"type": "match_go"}
		if admin_module:
			admin_module._sniff_packet("out", pid, msg, "tcp")
		session_manager.send_tcp(pid, msg)
