# modules/AdminModule.gd
extends Node
class_name AdminModule

var server_config := {}
var motd := ""

var authenticated_admins := {}
var admin_sniffing_enabled := {}   # player_id -> true/false

var scheduled_shutdown = {
	"active": false,
	"timestamp": 0,
	"restart": false
}

var last_warning_time := 0

var tcp_server: GameTCPServer = null
var udp_server: ENetServer = null
var gameplay: GameplayController = null
var tcp_connections: Dictionary = {}

func mark_admin(player_id: String):
	authenticated_admins[player_id] = true
	# preserve existing sniffing preference or default to false
	admin_sniffing_enabled[player_id] = admin_sniffing_enabled.get(player_id, false)

func unmark_admin(player_id: String):
	authenticated_admins.erase(player_id)
	admin_sniffing_enabled.erase(player_id)

func is_admin(player_id: String) -> bool:
	return authenticated_admins.has(player_id)

func load_server_config():
	var cfg := FileAccess.open("res://server_config.json", FileAccess.READ)
	if cfg:
		var parsed_cfg = JSON.parse_string(cfg.get_as_text())
		if typeof(parsed_cfg) == TYPE_DICTIONARY:
			server_config = parsed_cfg
			motd = server_config.get("motd", "")
	else:
		push_error("server_config.json missing")

func handle_admin_command(player_id: String, data: Dictionary):
	if not is_admin(player_id):
		return {"type": "admin_error", "reason": "not_authenticated"}

	var cmd = data.get("command", "")

	match cmd:
		"shutdown":
			_schedule_shutdown(0, false)
			return {"type": "admin_ack", "command": "shutdown", "action": "shutdown"}

		"restart":
			_schedule_shutdown(0, true)
			return {"type": "admin_ack", "command": "restart", "action": "restart"}

		"schedule_shutdown":
			_schedule_shutdown(data.hours, false)
			return {"type": "admin_ack", "command": "schedule_shutdown"}

		"schedule_restart":
			_schedule_shutdown(data.hours, true)
			return {"type": "admin_ack", "command": "schedule_restart"}

		"broadcast":
			_admin_broadcast(data.message)
			return {"type": "admin_ack", "command": "broadcast"}

		"set_motd":
			_admin_set_motd(data.message)
			return {"type": "admin_ack", "command": "set_motd"}

		"list_players":
			return _admin_list_players()

		"sniff_on":
			admin_sniffing_enabled[player_id] = true
			_log_admin_action(player_id, "sniff_on")
			return {"type":"admin_ack","command":"sniff_on","status":"enabled"}

		"sniff_off":
			admin_sniffing_enabled[player_id] = false
			_log_admin_action(player_id, "sniff_off")
			return {"type":"admin_ack","command":"sniff_off","status":"disabled"}

		_:
			return {"type": "admin_error", "reason": "unknown_command"}

func _admin_list_players() -> Dictionary:
	var result: Array = []
	# Prefer gameplay.player_registry if available, otherwise fallback to registry-like API
	var reg_players = {}
	if gameplay != null and gameplay.has_method("player_registry"):
		var pr = gameplay.player_registry
		if pr != null and pr.has_method("get_all_players"):
			reg_players = pr.get_all_players()
	# If no registry available, return empty list
	for player_id in reg_players.keys():
		var ps = reg_players[player_id]

		var tcp_connected := tcp_connections.has(player_id)
		var udp_connected := false
		if udp_server != null and udp_server.has_method("udp_peers"):
			udp_connected = udp_server.udp_peers.has(player_id)

		var match_ps = null
		if gameplay != null and gameplay.has_method("get_player_state"):
			match_ps = gameplay.get_player_state(player_id)

		result.append({
			"player_id": player_id,
			"username": ps.username,
			"status": ps.status,
			"tcp": tcp_connected,
			"udp": udp_connected,
			"team": (match_ps.team if match_ps else null),
			"health": (match_ps.health if match_ps else null),
			"position": (match_ps.position if match_ps else null)
		})

	return {
		"type": "admin_player_list",
		"players": result
	}

func _admin_broadcast(message: String):
	_broadcast({
		"type": "server_broadcast",
		"message": message
	})

func _admin_set_motd(new_motd: String):
	motd = new_motd
	server_config["motd"] = new_motd

	var f = FileAccess.open("res://server_config.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(server_config, "\t"))

	_broadcast({
		"type": "server_notice",
		"message": "MOTD updated by admin."
	})

func _broadcast(msg: Dictionary):
	for pid in tcp_connections.keys():
		_send_tcp(pid, msg)

func _send_tcp(player_id: String, msg: Dictionary):
	if tcp_connections.has(player_id):
		var conn: StreamPeerTCP = tcp_connections[player_id]
		var s := JSON.stringify(msg) + "\n"
		conn.put_data(s.to_utf8_buffer())

func _schedule_shutdown(hours: float, restart: bool):
	var seconds = int(hours * 3600)
	scheduled_shutdown.active = true
	scheduled_shutdown.timestamp = Time.get_unix_time_from_system() + seconds
	scheduled_shutdown.restart = restart
	last_warning_time = 0

	var action = "restart" if restart else "shutdown"
	var msg = "Scheduled %s in %s hour(s)" % [action, hours]

	_broadcast({"type": "server_notice", "message": msg})

func process_shutdown_timer():
	if not scheduled_shutdown.active:
		return null

	var now = Time.get_unix_time_from_system()
	var remaining = scheduled_shutdown.timestamp - now

	if remaining <= 0:
		return {"action": ("restart" if scheduled_shutdown.restart else "shutdown")}

	var warn_intervals = [3600, 1800, 600, 300, 60, 30, 10, 5, 1]

	for interval in warn_intervals:
		if remaining <= interval and last_warning_time != interval:
			last_warning_time = interval

			var action = "restart" if scheduled_shutdown.restart else "shutdown"
			var msg = "Server will %s in %d seconds" % [action, remaining]

			_broadcast({"type": "server_notice", "message": msg})
			break

	return null

# -------------------------
# Packet sniffing helper (for ALL packets)
# -------------------------
func _sniff_packet(direction: String, player_id: String, packet, source: String = "") -> void:
	# Convert packet to plain text for admin viewing
	var raw_text := ""
	var t = typeof(packet)

	if t == TYPE_DICTIONARY:
		raw_text = JSON.stringify(packet)
	elif t == TYPE_STRING:
		raw_text = packet
	elif t == TYPE_PACKED_BYTE_ARRAY:
		# Try UTF-8 decode; if non-printable bytes present, fall back to hex
		var bytes: PackedByteArray = packet
		var s := ""
		var printable := true
		for b in bytes:
			# build string safely
			s += char(b)
			if b < 32 and b != 9 and b != 10 and b != 13:
				printable = false
		if printable:
			raw_text = s
		else:
			raw_text = _bytes_to_hex(bytes)
	else:
		# For other types (int, float, Array, Object), stringify
		raw_text = str(packet)

	# Truncate very large payloads to avoid blocking admins and the network
	const MAX_RAW_LEN := 16384
	if raw_text.length() > MAX_RAW_LEN:
		raw_text = raw_text.substr(0, MAX_RAW_LEN) + "...(truncated)"

	var wrapper = {
		"type": "admin_sniff",
		"direction": direction,
		"player_id": player_id,
		"source": source,
		"timestamp": int(Time.get_unix_time_from_system() * 1000),
		"raw": raw_text
	}

	# forward as plain text message to all enabled and connected admins
	for admin_id in authenticated_admins.keys():
		if not admin_sniffing_enabled.get(admin_id, false):
			continue
		if not tcp_connections.has(admin_id):
			continue
		var conn: StreamPeerTCP = tcp_connections[admin_id]
		if conn == null:
			continue
		# ensure connection is in connected state before writing
		if conn.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			continue
		var s := JSON.stringify(wrapper) + "\n"
		conn.put_data(s.to_utf8_buffer())

func _bytes_to_hex(bytes: PackedByteArray) -> String:
	var out := ""
	for b in bytes:
		out += "%02x" % b
	return out

# -------------------------
# Audit logging helper
# -------------------------
func _log_admin_action(admin_id: String, action: String) -> void:
	print("ADMINMODULE: admin %s action: %s" % [admin_id, action])
