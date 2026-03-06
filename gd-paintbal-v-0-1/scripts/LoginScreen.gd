extends Control
class_name LoginScreen

@onready var username_input = $vbc/user/Username
@onready var password_input = $vbc/pass/Password
@onready var login_button   = $vbc/submit/Button
@onready var status_label   = $vbc/Status

@onready var nm = get_parent().get_parent()

func _ready():
	login_button.pressed.connect(_on_submit_pressed)

	nm.login_connected.connect(_on_login_connected)
	nm.login_failed.connect(_on_login_failed)
	nm.login_success.connect(_on_login_success)

	username_input.text_submitted.connect(_on_username_enter)
	password_input.text_submitted.connect(_on_submit_pressed)

func _on_username_enter(_text):
	password_input.grab_focus()

func _on_submit_pressed(_text = ""):
	status_label.text = "Connecting..."
	nm.start_login(username_input.text, password_input.text)

func _on_login_connected():
	self.visible = false

func _on_login_failed(reason):
	status_label.text = reason
	self.visible = true

func _on_login_success(player_id, token, role):
	pass
