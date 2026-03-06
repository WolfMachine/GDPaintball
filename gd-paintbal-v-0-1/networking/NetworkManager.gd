extends Node
class_name NetworkManager

signal login_connected
signal login_failed(reason)
signal login_success(player_id, token, role)

var tcp: TCPClient
var udp: UDPClient
var player_manager
var orchestrator   # module instance

var pending_username := ""
var pending_password := ""

var local_player_id := ""
var auth_token := ""

var login_timeout: Timer

# -------------------------
# KEEPALIVE
# -------------------------
var keepalive_interval := 5.0
var keepalive_accum := 0.0
# -------------------------

func _ready():
	tcp = $TCPClient
	udp = $UDPClient
	player_manager = get_node("../PlayerManager")

	# -----------------------------------------------------
	# CREATE ORCHESTRATOR AS A MODULE (NOT A NODE)
	# -----------------------------------------------------
	var OrchestratorClass = preload("res://scripts/systems/MatchClientOrchestrator.gd")
	orchestrator = OrchestratorClass.new()
	orchestrator.initialize(self, player_manager, null)
	# -----------------------------------------------------

	tcp.connect("connected", Callable(self, "_on_tcp_connected"))
	tcp.connect("disconnected", Callable(self, "_on_tcp_disconnected"))
	tcp.connect("message_received", Callable(self, "_on_tcp_message"))

	udp.connect("snapshot_received", Callable(self, "_on_udp_snapshot"))

	login_timeout = Timer.new()
	login_timeout.one_shot = true
	login_timeout.wait_time = 30.0
	add_child(login_timeout)
	login_timeout.timeout.connect(Callable(self, "_on_login_timeout"))

	set_process(true)


func _process(delta):
	if local_player_id != "" and auth_token != "":
		keepalive_accum += delta
		if keepalive_accum >= keepalive_interval:
			keepalive_accum = 0.0
			_send_keepalive()


func Send(channel: String, payload: Dictionary):
	if auth_token != "":
		payload["token"] = auth_token
	if local_player_id != "":
		payload["player_id"] = local_player_id

	match channel:
		"tcp":
			tcp.send(payload)
		"udp":
			udp.send_input(payload)


func start_login(username: String, password: String):
	pending_username = username
	pending_password = password
	login_timeout.start()
	tcp.connect_to_server("127.0.0.1", 9001)


func _on_login_timeout():
	emit_signal("login_failed", "Server unreachable")


func _on_tcp_connected():
	login_timeout.stop()
	emit_signal("login_connected")


func _on_tcp_disconnected():
	print("NET: TCP disconnected")


func _on_tcp_message(msg: Dictionary):
	print("NET: tcp message:", msg)

	match msg.type:
		"request_username":
			Send("tcp", {
				"type": "username",
				"value": pending_username
			})

		"request_password":
			Send("tcp", {
				"type": "password",
				"value": pending_password
			})

		"reject":
			login_timeout.stop()
			emit_signal("login_failed", msg.reason)

		"login_success":
			login_timeout.stop()
			local_player_id = msg.player_id
			auth_token = msg.token
			emit_signal("login_success", msg.player_id, msg.token, "player")

		"admin_login_success":
			login_timeout.stop()
			local_player_id = msg.player_id
			auth_token = msg.token
			emit_signal("login_success", msg.player_id, msg.token, "admin")

		"gm_login_success":
			login_timeout.stop()
			local_player_id = msg.player_id
			auth_token = msg.token
			emit_signal("login_success", msg.player_id, msg.token, "gm")

		"queued":
			print("NET: queued")

		# -------------------------
		# MATCH LIFECYCLE PACKETS
		# -------------------------

		"match_start":
			_handle_match_start(msg)

		"players_snapshot":
			orchestrator.on_players_snapshot(msg)

		"countdown":
			orchestrator.on_countdown(msg)

		"match_go":
			orchestrator.on_match_go()

		"match_end":
			orchestrator.on_match_end(msg)

		"player_joined":
			_handle_player_joined(msg)

		"player_left":
			print("NET: player_left for", msg.player_id)
			player_manager.remove_player(msg.player_id)


func _handle_match_start(msg: Dictionary):
	local_player_id = msg.player_id
	auth_token = msg.auth_token

	print("NET: match_start received. local_player_id=", local_player_id, "udp_port=", msg.udp_port)

	# UDP connection routed through NetworkManager
	connect_udp(msg.udp_port, local_player_id, auth_token)

	orchestrator.on_match_start(msg)


func connect_udp(port: int, pid: String, token: String) -> void:
	print("NET: connecting UDP on port", port)
	udp.connect_udp("127.0.0.1", port, pid, token)


func enable_input(enabled: bool) -> void:
	# Orchestrator calls this instead of touching UDP directly
	if udp and "enable_input" in udp:
		udp.enable_input = enabled


func _handle_player_joined(msg: Dictionary):
	print("NET: player_joined msg:", msg)

	var pid = msg.player_id
	var pos = Vector2(msg.position[0], msg.position[1])
	var heading = msg.heading

	player_manager.spawn_player(
		pid,
		pid == local_player_id,
		msg.username,
		msg.team,
		pos,
		heading
	)


func _on_udp_snapshot(snapshot: Dictionary):
	print("NET: udp packet received:", snapshot)
	player_manager.apply_snapshot(snapshot)


func _send_keepalive():
	var msg = {
		"type": "keepalive",
		"player_id": local_player_id,
		"token": auth_token
	}

	print("NET: sending keepalive:", msg)
	tcp.send(msg)
