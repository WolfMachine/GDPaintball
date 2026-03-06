extends Node
class_name Login

signal login_success(tcp_peer_id, username, player_id, state_dict)
signal admin_login_success(tcp_peer_id, username, player_id, state_dict)
signal gm_login_success(tcp_peer_id, username, player_id, state_dict)
signal login_rejected(tcp_peer_id, reason)
signal request_password(tcp_peer_id)

const TokenGenerator = preload("res://modules/TokenGenerator.gd")
var token_gen := TokenGenerator.new()

var pending := {}
var users := {}

func load_users():
	var f := FileAccess.open("res://users.json", FileAccess.READ)
	if f:
		var text := f.get_as_text()
		var parsed = JSON.parse_string(text)
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("users"):
			users = parsed["users"]
		else:
			push_error("users.json malformed")
	else:
		push_error("users.json missing")

func start_login(tcp_peer_id):
	pending[tcp_peer_id] = {
		"username": "",
		"awaiting_password": false
	}

func handle_username(tcp_peer_id, username: String):
	if not pending.has(tcp_peer_id):
		return

	if username == "" or username == null:
		username = "player_" + str(randi() % 99999)

	pending[tcp_peer_id]["username"] = username
	pending[tcp_peer_id]["awaiting_password"] = true

	emit_signal("request_password", tcp_peer_id)

func handle_password(tcp_peer_id, password: String):
	if not pending.has(tcp_peer_id):
		return

	var username = pending[tcp_peer_id]["username"]

	# GUEST SESSION (NOT PERSISTED)
	if not users.has(username):
		var new_id = token_gen.generate_player_id()
		emit_signal("login_success", tcp_peer_id, username, new_id, {})
		pending.erase(tcp_peer_id)
		return

	# EXISTING USER (PERSISTED)
	var entry = users[username]

	var stored_password = ""
	if typeof(entry) == TYPE_DICTIONARY and entry.has("password"):
		stored_password = entry["password"]

	if stored_password != password:
		emit_signal("login_rejected", tcp_peer_id, "Invalid password.")
		pending.erase(tcp_peer_id)
		return

	var player_id = ""
	if typeof(entry) == TYPE_DICTIONARY and entry.has("player_id"):
		player_id = entry["player_id"]

	var state_dict = {}
	if typeof(entry) == TYPE_DICTIONARY and entry.has("state"):
		state_dict = entry["state"]

	var role = "player"
	if typeof(entry) == TYPE_DICTIONARY and entry.has("role"):
		role = entry["role"]

	match role:
		"admin":
			emit_signal("admin_login_success", tcp_peer_id, username, player_id, state_dict)
		"gm":
			emit_signal("gm_login_success", tcp_peer_id, username, player_id, state_dict)
		_:
			emit_signal("login_success", tcp_peer_id, username, player_id, state_dict)

	pending.erase(tcp_peer_id)

func _save_users():
	var f = FileAccess.open("res://users.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"users": users}))

func handle_disconnect(tcp_peer_id):
	pending.erase(tcp_peer_id)
