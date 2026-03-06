# res://server/match/AIController.gd
extends Resource
class_name AIController

var owner: PlayerState = null
var match_controller = null

# -------------------------
# AI tuning parameters
# -------------------------
var desired_distance := 200.0
var move_speed := 200.0
var strafe_speed := 150.0
var fire_cooldown := 0.5
var fire_timer := 0.0

# Current target
var target: PlayerState = null

# -------------------------
# Initialization
# -------------------------
func init(owner_player: PlayerState, controller) -> void:
	owner = owner_player
	match_controller = controller

# -------------------------
# Tick (called by MatchController)
# -------------------------
func tick(delta: float) -> void:
	if owner == null or not owner.is_alive():
		return

	fire_timer = max(fire_timer - delta, 0.0)

	# Acquire or reacquire target
	if target == null or not target.is_alive():
		_pick_target()

	# No enemies left
	if target == null:
		owner.velocity = Vector2.ZERO
		return

	_update_movement(delta)
	_maybe_fire()

# -------------------------
# Target selection
# -------------------------
func _pick_target() -> void:
	var enemies = match_controller.players
	var best_dist := INF
	var best_target: PlayerState = null

	for p in enemies:
		if p.team == owner.team:
			continue
		if not p.is_alive():
			continue

		var d = owner.position.distance_to(p.position)
		if d < best_dist:
			best_dist = d
			best_target = p

	target = best_target

# -------------------------
# Movement logic
# -------------------------
func _update_movement(delta: float) -> void:
	if target == null or not target.is_alive():
		owner.velocity = Vector2.ZERO
		return

	var to_target = target.position - owner.position
	var distance = to_target.length()

	if distance == 0:
		owner.velocity = Vector2.ZERO
		return

	var dir_to_target = to_target / distance
	var move_dir := Vector2.ZERO

	# Maintain distance band
	if distance > desired_distance + 20.0:
		move_dir += dir_to_target
	elif distance < desired_distance - 20.0:
		move_dir -= dir_to_target

	# Add strafing
	var strafe_dir = dir_to_target.rotated(sign(randf() - 0.5) * PI * 0.5)
	move_dir += strafe_dir * 0.5

	if move_dir.length() > 0:
		move_dir = move_dir.normalized()

	owner.velocity = move_dir * move_speed

	# Update heading (AI aims at target)
	owner.heading = dir_to_target.angle()

# -------------------------
# Firing logic
# -------------------------
func _maybe_fire() -> void:
	if target == null or not target.is_alive():
		return

	if fire_timer > 0.0:
		return

	var to_target = target.position - owner.position
	var distance = to_target.length()

	# Only fire if within engagement range
	if distance > desired_distance * 1.5:
		return

	var dir = to_target.normalized()

	# Authoritative projectile spawn
	match_controller.spawn_projectile(owner.position, dir, owner.team, owner.id)

	fire_timer = fire_cooldown
