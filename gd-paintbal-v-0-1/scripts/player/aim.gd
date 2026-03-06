extends Sprite2D

@export var padding: float = 3.0
@export var rotation_offset_degrees: float = 0.0
@export var player_sprite_node: NodePath = "Sprite2D"

func _process(_delta: float) -> void:
	var body: CharacterBody2D = get_parent()
	var player = body.get_parent()
	var player_sprite: Sprite2D = body.get_node(player_sprite_node)

	if player_sprite.texture == null:
		return
	if texture == null:
		return

	var target: Vector2

	# LOCAL PLAYER → aim at mouse
	if player.state.is_local:
		target = get_global_mouse_position()

	# REMOTE PLAYER → aim using heading stored in player.state.heading
	else:
		var angle = player.state.heading
		var direction = Vector2.UP.rotated(angle)
		target = body.global_position + direction * 1000.0

	var to_target: Vector2 = target - body.global_position
	var angle: float = to_target.angle()

	var final_angle: float = angle + deg_to_rad(rotation_offset_degrees)
	rotation = final_angle

	var player_height: float = float(player_sprite.texture.get_height())
	var player_scale_y: float = player_sprite.scale.y
	var player_half: float = (player_height * player_scale_y) / 2.0

	var chevron_height: float = float(texture.get_height())
	var chevron_scale_y: float = scale.y
	var chevron_half: float = (chevron_height * chevron_scale_y) / 2.0

	var radius: float = player_half + padding + chevron_half

	position = Vector2(0, -radius).rotated(final_angle)
