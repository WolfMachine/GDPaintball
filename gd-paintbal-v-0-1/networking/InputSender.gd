extends Node

var nm
var player_manager

var last_vel: Vector2 = Vector2.ZERO
var last_heading: float = 0.0
var last_fire: bool = false

func _ready():
	nm = get_node("../../NetworkManager")
	player_manager = get_node("../../PlayerManager")

func _process(delta: float) -> void:
	var local_id = player_manager.local_player_id
	if local_id == "" or not player_manager.players.has(local_id):
		return

	var p = player_manager.players[local_id]

	# --- CURRENT INPUT STATE ---
	var vel: Vector2 = Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	if vel.length() > 0.0:
		vel = vel.normalized()

	var heading: float = (p.get_global_mouse_position() - p.global_position).angle()
	var fire: bool = Input.is_action_pressed("fire")

	# --- CHANGE DETECTION ---
	if vel == last_vel and abs(heading - last_heading) <= 0.001 and fire == last_fire:
		return

	# --- SEND INPUT THROUGH NETWORKMANAGER ---
	nm.Send("udp", {
		"vx": vel.x,
		"vy": vel.y,
		"h": heading,
		"f": fire
	})

	last_vel = vel
	last_heading = heading
	last_fire = fire
