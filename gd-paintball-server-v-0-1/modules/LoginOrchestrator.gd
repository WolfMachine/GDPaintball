extends Node
class_name LoginOrchestrator

var login_module
var registry
var session_manager
var queue_manager
var admin_module
var token_generator
var heartbeat_manager

func initialize(_login_module, _registry, _session_manager, _queue_manager, _admin_module, _token_generator, _heartbeat_manager):
	login_module = _login_module
	registry = _registry
	session_manager = _session_manager
	queue_manager = _queue_manager
	admin_module = _admin_module
	token_generator = _token_generator
	heartbeat_manager = _heartbeat_manager

	# Connect login signals
	login_module.login_success.connect(Callable(self, "_on_login_success"))
	login_module.admin_login_success.connect(Callable(self, "_on_admin_login_success"))
	login_module.gm_login_success.connect(Callable(self, "_on_gm_login_success"))
	login_module.login_rejected.connect(Callable(self, "_on_login_rejected"))
	login_module.request_password.connect(Callable(self, "_on_request_password"))

func start_login(tcp_peer_id):
	login_module.start_login(tcp_peer_id)

func handle_username(tcp_peer_id, username):
	login_module.handle_username(tcp_peer_id, username)

func handle_password(tcp_peer_id, password):
	login_module.handle_password(tcp_peer_id, password)

func validate_token(player_id, data: Dictionary) -> bool:
	var ps = registry.get_by_player_id(player_id)
	if ps == null:
		return false
	return data.get("token", "") == ps.auth_token

# ---------------------------------------------------------
# LOGIN CALLBACKS
# ---------------------------------------------------------

func _on_login_success(tcp_peer_id, username, player_id, state_dict):
	var ps = session_manager.create_player_session(tcp_peer_id, username, player_id)
	if ps == null:
		return

	queue_manager.add_player(player_id)

	if admin_module:
		admin_module._sniff_packet("out", player_id, {
			"type":"login_success",
			"player_id":player_id,
			"username":username
		}, "tcp")

	session_manager.send_tcp(player_id, {
		"type": "login_success",
		"player_id": player_id,
		"username": username
	})

func _on_admin_login_success(tcp_peer_id, username, player_id, state_dict):
	var ps = session_manager.create_player_session(tcp_peer_id, username, player_id)
	if ps == null:
		return

	session_manager.mark_admin(player_id)

	if admin_module:
		admin_module._sniff_packet("out", player_id, {
			"type":"admin_login_success",
			"player_id":player_id,
			"username":username
		}, "tcp")

	session_manager.send_tcp(player_id, {
		"type": "admin_login_success",
		"player_id": player_id,
		"username": username
	})

func _on_gm_login_success(tcp_peer_id, username, player_id, state_dict):
	var ps = session_manager.create_player_session(tcp_peer_id, username, player_id)
	if ps == null:
		return

	if admin_module:
		admin_module._sniff_packet("out", player_id, {
			"type":"gm_login_success",
			"player_id":player_id,
			"username":username
		}, "tcp")

	session_manager.send_tcp(player_id, {
		"type": "gm_login_success",
		"player_id": player_id,
		"username": username
	})

func _on_login_rejected(tcp_peer_id, reason):
	var player_id = registry.get_player_id_by_tcp(tcp_peer_id)

	if player_id != null:
		session_manager.reject(player_id, reason)
		return

	# Pre-auth reject
	if admin_module:
		admin_module._sniff_packet("out", str(tcp_peer_id), {
			"type":"reject",
			"reason":reason
		}, "tcp_preauth")

	session_manager.send_pre_auth(tcp_peer_id, {
		"type":"reject",
		"reason":reason
	})

	session_manager.drop_tcp_connection(tcp_peer_id)

func _on_request_password(tcp_peer_id):
	if admin_module:
		admin_module._sniff_packet("out", str(tcp_peer_id), {
			"type":"request_password"
		}, "tcp_preauth")

	session_manager.send_pre_auth(tcp_peer_id, {
		"type":"request_password"
	})
