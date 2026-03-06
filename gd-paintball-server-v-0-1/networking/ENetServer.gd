extends Node
class_name ENetServer

signal client_connected(id)
signal client_disconnected(id)
signal input_received(id, data)

var peer: ENetMultiplayerPeer = null
var port := 7777
var shutting_down := false

var player_tokens := {}   # player_id:String -> token:String
var udp_peers := {}       # player_id:String -> udp_peer_id:int
var peer_to_player := {}  # udp_peer_id:int -> player_id:String

func _ready():
	print("ENetServer ready (idle).")

func start_listening(p_port: int = 7777, max_clients: int = 64, channels: int = 1) -> int:
	if peer != null:
		return OK

	port = p_port
	peer = ENetMultiplayerPeer.new()
	var err = peer.create_server(port, max_clients, channels)
	if err != OK:
		push_error("Failed to start ENet server on port %d" % port)
		peer = null
		return err

	print("ENet server listening on port %d" % port)

	var mp = get_tree().get_multiplayer()
	mp.multiplayer_peer = peer

	mp.peer_connected.connect(_on_peer_connected)
	mp.peer_disconnected.connect(_on_peer_disconnected)
	mp.peer_packet.connect(_on_data_received)

	return OK

func stop_listening():
	if peer == null:
		return

	var mp = get_tree().get_multiplayer()

	var c_peer_connected := Callable(self, "_on_peer_connected")
	var c_peer_disconnected := Callable(self, "_on_peer_disconnected")
	var c_peer_packet := Callable(self, "_on_data_received")

	if mp.is_connected("peer_connected", c_peer_connected):
		mp.peer_connected.disconnect(c_peer_connected)
	if mp.is_connected("peer_disconnected", c_peer_disconnected):
		mp.peer_disconnected.disconnect(c_peer_disconnected)
	if mp.is_connected("peer_packet", c_peer_packet):
		mp.peer_packet.disconnect(c_peer_packet)

	peer.close()
	peer = null
	mp.multiplayer_peer = null

	udp_peers.clear()
	player_tokens.clear()
	peer_to_player.clear()

	print("ENet server stopped and UDP state cleared.")

func begin_shutdown():
	shutting_down = true
	stop_listening()

func drop_peer(id):
	if peer:
		peer.disconnect_peer(id)

	var to_remove := ""
	for pid in udp_peers.keys():
		if udp_peers[pid] == id:
			to_remove = pid
			break
	if to_remove != "":
		udp_peers.erase(to_remove)

	if peer_to_player.has(id):
		peer_to_player.erase(id)

func register_player_token(player_id: String, token: String):
	player_tokens[player_id] = token

func authenticate_udp_peer(peer_id: int, player_id: String, token: String) -> bool:
	if not player_tokens.has(player_id):
		print("UDP AUTH FAIL: unknown player", player_id)
		return false

	if player_tokens[player_id] != token:
		print("UDP AUTH FAIL: bad token for player", player_id)
		return false

	udp_peers[player_id] = peer_id
	peer_to_player[peer_id] = player_id
	print("UDP AUTH SUCCESS for player", player_id)

	var ack := {"type":"auth_ok","player_id":player_id}
	var bytes := var_to_bytes(ack)
	var mp = get_tree().get_multiplayer()
	if mp.multiplayer_peer != null:
		mp.send_bytes(bytes, peer_id)

	return true

func _on_peer_connected(id):
	if shutting_down:
		return
	print("UDP peer connected:", id)
	emit_signal("client_connected", id)

func _on_peer_disconnected(id):
	if shutting_down:
		return
	print("UDP peer disconnected:", id)

	var player_id := ""
	if peer_to_player.has(id):
		player_id = peer_to_player[id]
		peer_to_player.erase(id)

	var to_remove := ""
	for pid in udp_peers.keys():
		if udp_peers[pid] == id:
			to_remove = pid
			break
	if to_remove != "":
		udp_peers.erase(to_remove)

	emit_signal("client_disconnected", id)

func _on_data_received(peer_id: int, pkt: PackedByteArray):
	if shutting_down:
		return

	var data = bytes_to_var(pkt)
	if typeof(data) != TYPE_DICTIONARY:
		return

	if data.get("type", "") == "auth":
		var player_id: String = data.get("player_id", "")
		var token: String = data.get("token", "")

		if player_id == "":
			print("UDP AUTH FAIL: missing player_id")
			return

		authenticate_udp_peer(peer_id, player_id, token)
		return

	var player_id: String = data.get("player_id", "")
	if player_id == "":
		print("UDP REJECT: packet missing player_id")
		return

	if not udp_peers.has(player_id):
		print("UDP REJECT: unauthenticated packet from peer", peer_id)
		return

	if udp_peers[player_id] != peer_id:
		print("UDP SPOOF ATTEMPT: peer", peer_id, "pretending to be", player_id)
		return

	emit_signal("input_received", player_id, data)

func broadcast_snapshot(snapshot: Dictionary):
	if shutting_down or peer == null:
		return

	var bytes = var_to_bytes(snapshot)
	var mp = get_tree().get_multiplayer()

	mp.send_bytes(
		bytes,
		0,
		MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED
	)
