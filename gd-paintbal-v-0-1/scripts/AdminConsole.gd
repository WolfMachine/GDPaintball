extends Control
class_name AdminConsole

@onready var output = $VBoxContainer/TextEdit
@onready var input = $VBoxContainer/LineEdit
@onready var send_button = $VBoxContainer/Button

@onready var nm = get_parent().get_parent()

func _ready():
	self.visible = false

	await nm.ready

	send_button.pressed.connect(_on_send_pressed)
	input.text_submitted.connect(_on_send_pressed)

	nm.login_success.connect(_on_login_success)
	nm.tcp.message_received.connect(_on_server_message)

func _on_login_success(player_id, token, role):
	if role == "admin" or role == "gm":
		self.visible = true
		_log("[system] admin console enabled")

func _on_send_pressed(_text = ""):
	var cmd = input.text.strip_edges()
	if cmd == "":
		return

	_log("> " + cmd)

	nm.Send("tcp", {
		"type": "admin_command",
		"command": cmd
	})

	input.text = ""

func _on_server_message(msg: Dictionary):
	_log(str(msg))

func _log(text: String):
	output.text += text + "\n"
	output.scroll_vertical = output.get_line_count()
