extends Node
class_name HeartbeatManager

var heartbeat
var session_manager
var match_lifecycle
var admin_module

func initialize(_heartbeat, _session_manager, _match_lifecycle, _admin_module):
	heartbeat = _heartbeat
	session_manager = _session_manager
	match_lifecycle = _match_lifecycle
	admin_module = _admin_module

	heartbeat.timed_out.connect(Callable(self, "_on_heartbeat_timed_out"))

# ---------------------------------------------------------
# BASIC OPERATIONS
# ---------------------------------------------------------

func register(player_id):
	if heartbeat:
		heartbeat.register(player_id)

func unregister(player_id):
	if heartbeat:
		heartbeat.unregister(player_id)

func touch(player_id):
	if heartbeat:
		heartbeat.touch(player_id)

# ---------------------------------------------------------
# TIMEOUT HANDLING
# ---------------------------------------------------------

func _on_heartbeat_timed_out(player_id: String) -> void:
	# Admins never time out
	if session_manager.admin_connections.has(player_id):
		return

	# Sniff timeout event
	if admin_module:
		admin_module._sniff_packet("in", player_id, {
			"event":"heartbeat_timed_out",
			"player_id":player_id
		}, "heartbeat")

	# Cleanup path mirrors disconnect
	match_lifecycle.handle_player_disconnected(player_id)
	unregister(player_id)
	session_manager.handle_disconnect(player_id)
