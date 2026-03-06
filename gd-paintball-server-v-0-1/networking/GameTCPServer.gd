extends Node
class_name GameTCPServer

signal client_connected(tcp_peer_id, conn)
signal client_disconnected(tcp_peer_id)
signal data_received(tcp_peer_id, data)

var server := TCPServer.new()
var connections := {}        # tcp_peer_id -> StreamPeerTCP
var buffers := {}            # tcp_peer_id -> String buffer (NDJSON)
var next_tcp_peer_id := 1

var port := 9001
var shutting_down := false


func _ready():
	var err = server.listen(port)
	if err != OK:
		push_error("Failed to start TCP server on port %d" % port)
		return

	print("TCP server listening on port %d" % port)
	set_process(true)


func begin_shutdown():
	shutting_down = true


func drop_connection(tcp_peer_id):
	if connections.has(tcp_peer_id):
		var conn: StreamPeerTCP = connections[tcp_peer_id]
		if conn:
			print("SERVER: drop_connection() disconnecting peer", tcp_peer_id)
			conn.disconnect_from_host()
		_handle_disconnect(tcp_peer_id)


func _process(_delta):
	if shutting_down:
		return

	# ---------------------------------------------------------
	# ACCEPT NEW CONNECTIONS
	# ---------------------------------------------------------
	if server.is_connection_available():
		var conn: StreamPeerTCP = server.take_connection()
		var tcp_peer_id = next_tcp_peer_id
		next_tcp_peer_id += 1

		connections[tcp_peer_id] = conn
		buffers[tcp_peer_id] = ""

		print("SERVER: ACCEPTED CONNECTION peer_id =", tcp_peer_id, "conn =", conn)
		emit_signal("client_connected", tcp_peer_id, conn)
		print("SERVER: EMITTED client_connected SIGNAL")

	# ---------------------------------------------------------
	# PROCESS EXISTING CONNECTIONS
	# ---------------------------------------------------------
	for tcp_peer_id in connections.keys().duplicate():

		var conn: StreamPeerTCP = connections.get(tcp_peer_id, null)
		if conn == null:
			_handle_disconnect(tcp_peer_id)
			continue

		var status := conn.get_status()

		# ---------------------------------------------------------
		# GODOT 4 FIX: get_status() DOES NOT REPORT DISCONNECTS
		# We must attempt a read to detect closed sockets.
		# ---------------------------------------------------------
		if status != StreamPeerTCP.STATUS_CONNECTED:
			_handle_disconnect(tcp_peer_id)
			continue

		# Try reading ANYTHING — this is what reveals disconnects
		var available := conn.get_available_bytes()

		if available == 0:
			# No data, but still connected — continue
			continue

		var chunk = conn.get_partial_data(available)

		# If read failed, the socket is dead
		if chunk[0] != OK:
			_handle_disconnect(tcp_peer_id)
			continue

		# ---------------------------------------------------------
		# SAFE UTF‑8 FALLBACK
		# ---------------------------------------------------------
		var bytes: PackedByteArray = chunk[1]
		var raw_utf8 := bytes.get_string_from_utf8()
		var raw: String

		if raw_utf8 != "":
			raw = raw_utf8
		else:
			raw = ""
			for b in bytes:
				raw += char(b)

		buffers[tcp_peer_id] += raw

		# ---------------------------------------------------------
		# NDJSON LINE PARSING
		# ---------------------------------------------------------
		while buffers[tcp_peer_id].find("\n") != -1:
			var newline_index: int = buffers[tcp_peer_id].find("\n")
			var line: String = buffers[tcp_peer_id].substr(0, newline_index)
			buffers[tcp_peer_id] = buffers[tcp_peer_id].substr(newline_index + 1)

			line = line.strip_edges()
			if line == "":
				continue

			var data = JSON.parse_string(line)
			if typeof(data) == TYPE_DICTIONARY:
				emit_signal("data_received", tcp_peer_id, data)
			else:
				print("SERVER: JSON PARSE ERROR FROM", tcp_peer_id, ":", line)


func _handle_disconnect(tcp_peer_id):
	if not connections.has(tcp_peer_id):
		return

	print("SERVER: DISCONNECT peer_id =", tcp_peer_id)

	connections.erase(tcp_peer_id)
	buffers.erase(tcp_peer_id)

	emit_signal("client_disconnected", tcp_peer_id)
