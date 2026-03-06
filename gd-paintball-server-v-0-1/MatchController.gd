extends Node
class_name MatchController

const Config = preload("res://config.gd")
const PlayerState = preload("res://state/PlayerState.gd")
const ProjectileState = preload("res://state/ProjectileState.gd")
const WorldGeometry = preload("res://world/WorldGeometry.gd")

enum MatchState {
	WAITING,
	RUNNING,
	ENDED
}

var players: Array[PlayerState] = []
var projectiles: Array[ProjectileState] = []

var match_state: int = MatchState.WAITING
var time: float = 0.0

var world_geometry: WorldGeometry

func reset():
	players.clear()
	projectiles.clear()
	match_state = MatchState.WAITING
	time = 0.0
	print("MatchController: Reset complete.")

func tick(delta: float) -> void:
	if match_state != MatchState.RUNNING:
		return

	time += delta

	_apply_input_to_velocity()
	_simulate_players(delta)
	_resolve_player_vs_player()

	_spawn_projectiles()
	_step_projectiles()
	_check_projectile_collisions()
	_cleanup()

func _apply_input_to_velocity() -> void:
	for p in players:
		if not p.is_alive():
			p.velocity = Vector2.ZERO
			continue

		if p.move_input.length() > 0.001:
			p.velocity = p.move_input.normalized() * p.speed
		else:
			p.velocity = Vector2.ZERO

func _simulate_players(delta: float) -> void:
	for p in players:
		if not p.is_alive():
			continue

		var P0 = p.position
		var P1 = P0 + p.velocity * delta

		if world_geometry:
			P1 = world_geometry.collide_player(P0, P1, p.collider_radius)

		p.position = P1

func _resolve_player_vs_player() -> void:
	var count := players.size()

	for i in count:
		var A = players[i]
		if not A.is_alive():
			continue

		for j in range(i + 1, count):
			var B = players[j]
			if not B.is_alive():
				continue

			var delta = B.position - A.position
			var dist = delta.length()
			var min_dist = A.collider_radius + B.collider_radius

			if dist < min_dist and dist > 0.0001:
				var penetration = min_dist - dist
				var normal = delta / dist

				A.position -= normal * (penetration * 0.5)
				B.position += normal * (penetration * 0.5)

func _spawn_projectiles() -> void:
	for p in players:
		if not p.is_alive():
			continue
		if not p.fire_request:
			continue

		p.fire_request = false

		var dir = Vector2.UP.rotated(p.heading).normalized()
		var start = p.position + dir * (p.collider_radius + Config.MUZZLE_OFFSET)

		var pr := ProjectileState.new()
		pr.owner_id = p.id
		pr.team = p.team
		pr.origin = start
		pr.direction = dir
		pr.power = p.power
		pr.damage = p.projectile_damage
		pr.traveled = 0.0
		pr.tick_counter = 0
		pr.alive = true

		projectiles.append(pr)

func _step_projectiles() -> void:
	for pr in projectiles:
		if not pr.alive:
			continue

		pr.tick_counter += 1
		if pr.tick_counter < Config.SEGMENT_TICKS:
			continue

		pr.tick_counter = 0

		var segment_length = pr.power / Config.PROJECTILE_DIVISOR
		pr.traveled += segment_length

		if pr.traveled >= pr.power:
			pr.alive = false

func _check_projectile_collisions() -> void:
	for pr in projectiles:
		if not pr.alive:
			continue

		var segment_length = pr.power / Config.PROJECTILE_DIVISOR

		var start = pr.origin + pr.direction * pr.traveled
		var end = pr.origin + pr.direction * min(pr.traveled + segment_length, pr.power)

		for target in players:
			if not target.is_alive():
				continue
			if target.team == pr.team:
				continue

			if Geometry2D.segment_intersects_circle(start, end, target.position, target.collider_radius):
				target.health -= pr.damage
				pr.alive = false
				break

func _cleanup() -> void:
	projectiles = projectiles.filter(func(pr): return pr.alive)
