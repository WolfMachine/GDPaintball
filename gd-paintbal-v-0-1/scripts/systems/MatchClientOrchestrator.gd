extends Object
class_name MatchClientOrchestrator

enum Phase {
	NONE,
	MATCH_START_RECEIVED,
	REQUESTING_PLAYERS,
	WAITING_FOR_SNAPSHOT,
	READY_SENT,
	COUNTDOWN,
	RUNNING,
	ENDED
}

var phase := Phase.NONE

var network          # NetworkManager
var player_manager   # PlayerManager
var ui_manager       # optional

var local_player_id := ""
var auth_token := ""

# ---------------------------------------------------------
# INITIALIZATION
# ---------------------------------------------------------

func initialize(_network, _player_manager, _ui_manager) -> void:
	network = _network
	player_manager = _player_manager
	ui_manager = _ui_manager

	print("\n=== CLIENT ORCHESTRATOR INITIALIZED (MODULE) ===\n")

# ---------------------------------------------------------
# MATCH START
# ---------------------------------------------------------

func on_match_start(msg: Dictionary) -> void:
	phase = Phase.MATCH_START_RECEIVED

	local_player_id = msg.player_id
	auth_token = msg.auth_token

	print("\n=== MATCH START RECEIVED ===")
	print("Local Player:", local_player_id)
	print("UDP Port:", msg.udp_port)
	print("NetworkManager already connected UDP.\n")

	_request_players()

# ---------------------------------------------------------
# PLAYERS SNAPSHOT
# ---------------------------------------------------------

func on_players_snapshot(msg: Dictionary) -> void:
	if phase != Phase.REQUESTING_PLAYERS and phase != Phase.WAITING_FOR_SNAPSHOT:
		print("SNAPSHOT IGNORED (wrong phase:", phase, ")")
		return

	phase = Phase.WAITING_FOR_SNAPSHOT

	print("\n=== PLAYERS SNAPSHOT RECEIVED ===")
	print("Players:", msg.players.keys(), "\n")

	# 🔥 FIXED: pass local_player_id
	player_manager.spawn_from_snapshot(msg.players, local_player_id)

	_send_ready()

# ---------------------------------------------------------
# COUNTDOWN
# ---------------------------------------------------------

func on_countdown(msg: Dictionary) -> void:
	phase = Phase.COUNTDOWN

	print("\n=== COUNTDOWN ===")
	print("Match begins in:", msg.value, "\n")

# ---------------------------------------------------------
# MATCH GO
# ---------------------------------------------------------

func on_match_go() -> void:
	phase = Phase.RUNNING

	print("\n=== MATCH GO ===")
	print("Enabling input and starting simulation.\n")

	network.enable_input(true)

# ---------------------------------------------------------
# MATCH END
# ---------------------------------------------------------

func on_match_end(msg: Dictionary) -> void:
	phase = Phase.ENDED

	print("\n=== MATCH END ===")
	print("Winner Team:", msg.winner)
	print("Cleaning up players...\n")

	network.enable_input(false)
	player_manager.clear_all_players()

# ---------------------------------------------------------
# INTERNAL SEND HELPERS
# ---------------------------------------------------------

func _request_players() -> void:
	phase = Phase.REQUESTING_PLAYERS

	print("\n=== REQUESTING PLAYERS FROM SERVER ===\n")

	network.Send("tcp", {
		"type": "request_players"
	})

func _send_ready() -> void:
	phase = Phase.READY_SENT

	print("\n=== SENDING READY TO SERVER ===\n")

	network.Send("tcp", {
		"type": "ready"
	})
