extends CharacterBody2D

@export var move_speed: float = 300.0

func _physics_process(_delta: float) -> void:
	var player = get_parent()

	# Local player movement uses input
	if player.state.is_local:
		var input_vector = Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
		)

		if input_vector != Vector2.ZERO:
			input_vector = input_vector.normalized()

		velocity = input_vector * move_speed
		move_and_slide()

	else:
		# Remote players do not move themselves
		# They will be positioned by PlayerManager later
		velocity = Vector2.ZERO
