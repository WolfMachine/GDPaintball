extends Node
class_name SessionManager

# ---------------------------------------------------------
# DEPENDENCIES
# ---------------------------------------------------------

var registry
var token_generator
var heartbeat_manager
var admin_module
var queue_manager

var tcp_server
var udp_server
var login_orchestrator
var match_orchestrator

# ---------------------------------------------------------
# CONNECTION STATE (single source of truth)
# ---------------------------------------------------------

var tcp_connections_by_peer_id := {}   # tcp_peer_id -> StreamPeerTCP
var tcp_connections := {}              # player_id -> StreamPeerTCP
var admin_connections := {}            # player_id -> true

# ---------------------------------------------------------
# INITIALIZATION
# ---------------------------------------------------------

func initialize(
	_tcp_server,
	_udp_server,
	_registry,
	_token_generator,
	_heartbeat_manager,
	_admin_module,
	_queue_manager,
	_login_orchestrator,
	_match_orchestrator
):
	tcp_server = _tcp_server
	udp_server = _udp_server
	registry = _registry
	token_generator = _token_generator
	heartbeat_manager = _heartbeat_manager
	admin_module = _admin_module
	queue_manager = _queue_manager
	login_orchestrator = _login_orchestrator
	match_orchestrator = _match_orchestrator

	# TCP signals
	tcp_server.client_connected.connect(Callable(self, "_on_tcp_client_connected"))
	tcp_server.client_disconnected.connect(Callable(self, "_on_tcp_client_disconnected"))
	tcp_server.data_received.connect(Callable(self, "_on_tcp_data_received"))

	# UDP signals
	udp_server.client_connected.connect(Callable(self, "_on_udp_client_connected"))
	udp_server.client_disconnected.connect(Callable(self, "_on_udp_client_disconnected"))
	udp_server.input_received.connect(Callable(self, "_on_udp_input_received"))

# ---------------------------------------------------------
# TCP CONNECTION + LOGIN HANDSHAKE
# ---------------------------------------------------------

func _on_tcp_client_connected(tcp_peer_id, conn):
	tcp_connections_by_peer_id[tcp_peer_id] = conn

	login_orchestrator.start_login(tcp_peer_id)

	if admin_module:
		admin_module._sniff_packet("out", str(tcp_peer_id), {"type":"request_username"}, "tcp_preauth")

	send_tcp_raw(conn, {"type": "request_username"})

func _on_tcp_client_disconnected(tcp_peer_id):
	var player_id = _get_player_id_by_tcp(tcp_peer_id)

	if player_id == null:
		if admin_module:
			admin_module._sniff_packet("in", str(tcp_peer_id), {"event":"tcp_client_disconnected"}, "tcp_preauth")
		tcp_connections_by_peer_id.erase(tcp_peer_id)
		return

	if admin_module:
		admin_module._sniff_packet("in", player_id, {"event":"tcp_client_disconnected"}, "tcp")

	handle_disconnect(player_id)

func _on_tcp_data_received(tcp_peer_id, data: Dictionary):
	# PRE-AUTH
	if data.type == "username":
		login_orchestrator.handle_username(tcp_peer_id, data.value)
		return

	if data.type == "password":
		login_orchestrator.handle_password(tcp_peer_id, data.value)
		return

	# LOOKUP SESSION
	var player_id = _get_player_id_by_tcp(tcp_peer_id)
	if player_id == null:
		if admin_module:
			admin_module._sniff_packet("in", str(tcp_peer_id), data, "tcp_preauth")
		return

	# TOKEN VALIDATION
	if not login_orchestrator.validate_token(player_id, data):
		reject(player_id, "Invalid token.")
		return

	# HEARTBEAT TOUCH
	if heartbeat_manager:
		heartbeat_manager.touch(player_id)

	# ADMIN COMMANDS
	if admin_connections.has(player_id) and data.type == "admin_command":
		var result = admin_module.handle_admin_command(player_id, data)
		if result != null:
			send_tcp(player_id, result)
		return

	# NORMAL PLAYER PACKET
	match_orchestrator.handle_player_packet(player_id, data)

# ---------------------------------------------------------
# UDP
# ---------------------------------------------------------

func _on_udp_client_connected(peer_id):
	if admin_module:
		admin_module._sniff_packet("in", str(peer_id), {"event":"udp_client_connected"}, "udp")

func _on_udp_client_disconnected(peer_id):
	var player_id = _get_player_id_by_udp(peer_id)

	if admin_module:
		var sniff_id = player_id if player_id != null else str(peer_id)
		admin_module._sniff_packet("in", sniff_id, {"event":"udp_client_disconnected"}, "udp")

	if player_id != null:
		handle_disconnect(player_id)

func _on_udp_input_received(player_id: String, input_data):
	if admin_module:
		admin_module._sniff_packet("in", player_id, input_data, "udp")

	if heartbeat_manager:
		heartbeat_manager.touch(player_id)

	match_orchestrator.apply_input(player_id, input_data)

# ---------------------------------------------------------
# SESSION CREATION
# ---------------------------------------------------------

func create_player_session(tcp_peer_id, username, player_id):
	var conn = tcp_connections_by_peer_id.get(tcp_peer_id)
	if conn == null:
		return null

	var ps = PlayerState.new()
	ps.id = player_id
	ps.client_id = tcp_peer_id
	ps.username = username
	ps.is_human = true
	ps.status = PlayerState.Status.QUEUED
	ps.auth_token = token_generator.generate_auth_token(player_id)

	ps.team = 0
	ps.kills = 0
	ps.assists = 0
	ps.deaths = 0
	ps.position = Vector2.ZERO
	ps.velocity = Vector2.ZERO
	ps.heading = 0.0
	ps.health = 100

	registry.players[player_id] = ps
	registry.by_tcp[tcp_peer_id] = player_id
	registry.by_token[ps.auth_token] = player_id

	tcp_connections[player_id] = conn
	tcp_connections_by_peer_id.erase(tcp_peer_id)

	if heartbeat_manager:
		heartbeat_manager.register(player_id)

	if admin_module:
		admin_module._sniff_packet("out", player_id, {
			"event":"session_created",
			"player_id":player_id,
			"username":username
		}, "server")

	return ps

# ---------------------------------------------------------
# ADMIN FLAGGING
# ---------------------------------------------------------

func mark_admin(player_id):
	admin_connections[player_id] = true
	if admin_module:
		admin_module.mark_admin(player_id)
		admin_module.admin_sniffing_enabled[player_id] = true

# ---------------------------------------------------------
# DISCONNECT HANDLING (UPDATED)
# ---------------------------------------------------------

func handle_disconnect(player_id):
	var ps = registry.get_by_player_id(player_id)
	if ps == null:
		return

	var client_id = ps.client_id

	# Use the orchestrator’s reference to GameplayController
	if match_orchestrator and match_orchestrator.gameplay:
		match_orchestrator.gameplay.remove_player(player_id)

	if heartbeat_manager:
		heartbeat_manager.unregister(player_id)

	queue_manager.remove_player(player_id)
	registry.remove_player(player_id)

	tcp_connections.erase(player_id)
	admin_connections.erase(player_id)

	if tcp_server:
		tcp_server.drop_connection(client_id)

# ---------------------------------------------------------
# REJECT
# ---------------------------------------------------------

func reject(player_id, reason):
	var conn = tcp_connections.get(player_id)
	if conn:
		if admin_module:
			admin_module._sniff_packet("out", player_id, {"type":"reject","reason":reason}, "tcp")
		send_tcp_raw(conn, {"type":"reject","reason":reason})

	var ps = registry.get_by_player_id(player_id)
	if ps:
		tcp_server.drop_connection(ps.client_id)

# ---------------------------------------------------------
# TCP SEND HELPERS
# ---------------------------------------------------------

func send_tcp(player_id: String, msg):
	var conn = tcp_connections.get(player_id)
	if conn == null:
		return

	var ps = registry.get_by_player_id(player_id)
	if ps:
		msg.token = ps.auth_token

	if admin_module:
		admin_module._sniff_packet("out", player_id, msg, "tcp")

	conn.put_data((JSON.stringify(msg) + "\n").to_utf8_buffer())

func send_tcp_raw(conn, msg):
	if admin_module:
		admin_module._sniff_packet("out", "", msg, "tcp_preauth")

	conn.put_data((JSON.stringify(msg) + "\n").to_utf8_buffer())

# ---------------------------------------------------------
# PRE-AUTH SEND HELPER (NEW)
# ---------------------------------------------------------

func send_pre_auth(tcp_peer_id, msg):
	var conn = tcp_connections_by_peer_id.get(tcp_peer_id)
	if conn:
		send_tcp_raw(conn, msg)

# ---------------------------------------------------------
# INTERNAL HELPERS
# ---------------------------------------------------------

func _get_player_id_by_tcp(tcp_peer_id):
	var ps = registry.get_by_tcp(tcp_peer_id)
	return ps.id if ps != null else null

func _get_player_id_by_udp(udp_peer_id):
	var ps = registry.get_by_udp(udp_peer_id)
	return ps.id if ps != null else null
