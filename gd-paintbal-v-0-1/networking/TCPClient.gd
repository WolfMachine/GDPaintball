extends Node
class_name TCPClient

signal message_received(msg)
signal connected
signal disconnected

var tcp := StreamPeerTCP.new()
var connected_flag := false
var buffer := ""

func connect_to_server(ip: String, port: int):
	var err = tcp.connect_to_host(ip, port)
	if err != OK:
		push_error("TCP connect failed")
		return
	set_process(true)

func _process(delta):
	tcp.poll()
	var status = tcp.get_status()

	if status == StreamPeerTCP.STATUS_CONNECTED:
		if not connected_flag:
			connected_flag = true
			emit_signal("connected")

		while tcp.get_available_bytes() > 0:
			var chunk = tcp.get_partial_data(tcp.get_available_bytes())
			if chunk[0] != OK:
				break

			# Cast to PackedByteArray so Godot knows the type
			var bytes := chunk[1] as PackedByteArray
			var text := bytes.get_string_from_utf8()
			buffer += text

			while buffer.find("\n") != -1:
				var newline_index = buffer.find("\n")
				var line = buffer.substr(0, newline_index)
				buffer = buffer.substr(newline_index + 1)

				line = line.strip_edges()
				if line == "":
					continue

				var msg = JSON.parse_string(line)
				if typeof(msg) == TYPE_DICTIONARY:
					emit_signal("message_received", msg)

	elif connected_flag:
		connected_flag = false
		emit_signal("disconnected")
		set_process(false)

func send(msg: Dictionary):
	if tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		var s = JSON.stringify(msg) + "\n"
		tcp.put_data(s.to_utf8_buffer())
