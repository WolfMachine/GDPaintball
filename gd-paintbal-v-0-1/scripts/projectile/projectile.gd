extends Node2D

@export var projectile_width: float = 2.0
@export var color: Color = Color.WHITE
@export var testing_mode: bool = true
@export var testing_lifetime: float = 3.0

var start_global: Vector2
var end_global: Vector2

func _ready() -> void:
	# Convert global → local
	var start_local = to_local(start_global)
	var end_local = to_local(end_global)

	var line: Line2D = get_node("Line2D")
	line.width = projectile_width
	line.default_color = color

	line.clear_points()
	line.add_point(start_local)
	line.add_point(end_local)

	print("Projectile:")
	print("  Global pos:   ", global_position)
	print("  Start local:  ", start_local)
	print("  End local:    ", end_local)
	print("------------------------------")

	if testing_mode:
		await get_tree().create_timer(testing_lifetime).timeout
		queue_free()
