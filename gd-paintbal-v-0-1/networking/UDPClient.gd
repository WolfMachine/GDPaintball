extends Node
class_name UDPClient

signal snapshot_received(snapshot)

var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var player_id: String = ""
var token: String = ""

var connected := false

# ---------------------------------------------------------
# RESET PEER (safe reconnect)
# ---------------------------------------------------------
func reset_peer():
	if peer != null:
		peer.close()
	peer = ENetMultiplayerPeer.new()
	connected = false

# ---------------------------------------------------------
# CONNECT UDP
# ---------------------------------------------------------
func connect_udp(ip: String, port: int, id: String, auth: String):
	reset_peer()

	player_id = id
	token = auth

	var err = peer.create_client(ip, port)
	if err != OK:
		push_error("UDP connect failed")
		return

	var mp := get_tree().get_multiplayer()
	mp.multiplayer_peer = peer

	# Connect signals only once
	if not connected:
		mp.connected_to_server.connect(_on_connected)
		mp.peer_packet.connect(_on_packet)
		connected = true

# ---------------------------------------------------------
# AUTH PACKET
# ---------------------------------------------------------
func _on_connected():
	var auth_packet: Dictionary = {
		"type": "auth",
		"player_id": player_id,
		"token": token
	}

	var bytes: PackedByteArray = var_to_bytes(auth_packet)
	var mp := get_tree().get_multiplayer()

	if mp.multiplayer_peer != null \
	and mp.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		mp.send_bytes(bytes, 0)

# ---------------------------------------------------------
# PACKET HANDLER
# ---------------------------------------------------------
func _on_packet(peer_id: int, pkt: PackedByteArray):
	if pkt.size() == 0:
		return

	var data: Variant = bytes_to_var(pkt)
	if typeof(data) != TYPE_DICTIONARY:
		return

	# 🔥 Server snapshots ALWAYS contain "p"
	if data.has("p"):
		emit_signal("snapshot_received", data)

# ---------------------------------------------------------
# SEND INPUT
# ---------------------------------------------------------
func send_input(packet: Dictionary):
	var mp := get_tree().get_multiplayer()
	var mp_peer := mp.multiplayer_peer

	if mp_peer == null:
		return

	if mp_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return

	var bytes: PackedByteArray = var_to_bytes(packet)
	mp.send_bytes(bytes, 0)
