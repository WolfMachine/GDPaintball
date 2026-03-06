extends Node

@export var projectile_scene: PackedScene
@export var fire_button: String = "fire"
@export var projectile_power: float = 200.0
@export var projectile_width: float = 2.0
@export var player_offset_px: float = 1.0

func _process(_delta: float) -> void:
	var player = get_parent().get_parent()

	# LOCAL PLAYER → fires on button press
	if player.state.is_local and Input.is_action_just_pressed(fire_button):
		_fire_projectile()

	# REMOTE PLAYER → fires when PlayerManager sets fire_request = true
	if not player.state.is_local and player.state.fire_request:
		_fire_projectile()
		player.state.fire_request = false  # consume the event


func _fire_projectile() -> void:
	var body: CharacterBody2D = get_parent()
	var sprite: Sprite2D = body.get_node("Sprite2D")
	var chevron: Sprite2D = body.get_node("Marker")
	var player = body.get_parent()

	# LOCAL PLAYER → use chevron rotation (mouse aim)
	# REMOTE PLAYER → use heading from PlayerState
	var angle: float = chevron.global_rotation if player.state.is_local else player.state.heading

	var direction: Vector2 = Vector2.UP.rotated(angle).normalized()

	var player_width: float = float(sprite.texture.get_width())
	var player_scale_x: float = sprite.scale.x
	var player_radius: float = (player_width * player_scale_x) / 2.0

	var player_scale: Vector2 = player.global_scale

	var start_offset: float = player_radius + player_offset_px + (projectile_width / 2.0)

	var start_point: Vector2 = body.global_position + (direction * start_offset * player_scale.y)
	var end_point: Vector2 = start_point + (direction * projectile_power)

	print("---- FIRE DEBUG ----")
	print("Player position:      ", body.global_position)
	print("Start point:          ", start_point)
	print("End point:            ", end_point)
	print("Direction:            ", direction)
	print("Angle (deg):          ", rad_to_deg(angle))
	print("----------------------")

	var p = projectile_scene.instantiate()
	p.start_global = start_point
	p.end_global = end_point
	p.global_position = start_point

	get_tree().current_scene.add_child(p)
