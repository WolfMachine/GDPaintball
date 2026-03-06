class_name WorldGeometry
extends Resource

const Config = preload("res://config.gd")

# ------------------------------------------------------------
# World Geometry Storage
# ------------------------------------------------------------
var walls: Array = []      # each: { a: Vector2, b: Vector2 }
var circles: Array = []    # each: { center: Vector2, radius: float }


# ------------------------------------------------------------
# PUBLIC ENTRY POINT
# Swept-circle collision for a player moving from start → end.
# ------------------------------------------------------------
func collide_player(start: Vector2, end: Vector2, radius: float) -> Vector2:
	var corrected := end

	# 1. Collide with world walls (line segments)
	for w in walls:
		corrected = _swept_circle_vs_segment(start, corrected, radius, w.a, w.b)

	# 2. Collide with circular obstacles
	for c in circles:
		corrected = _swept_circle_vs_circle(start, corrected, radius, c.center, c.radius)

	# 3. Collide with play area AABB
	corrected = _collide_with_bounds(corrected, radius)

	return corrected


# ------------------------------------------------------------
# AABB BOUNDS COLLISION (play area)
# ------------------------------------------------------------
func _collide_with_bounds(pos: Vector2, radius: float) -> Vector2:
	pos.x = clamp(pos.x, Config.PLAY_AREA_MIN.x + radius, Config.PLAY_AREA_MAX.x - radius)
	pos.y = clamp(pos.y, Config.PLAY_AREA_MIN.y + radius, Config.PLAY_AREA_MAX.y - radius)
	return pos


# ------------------------------------------------------------
# SWEPT CIRCLE vs CIRCLE
# ------------------------------------------------------------
func _swept_circle_vs_circle(start: Vector2, end: Vector2, r: float, center: Vector2, cr: float) -> Vector2:
	var total_r = r + cr
	var movement = end - start

	# Vector from obstacle to start
	var f = start - center

	var a = movement.dot(movement)
	if a == 0.0:
		return end

	var b = 2.0 * f.dot(movement)
	var c = f.dot(f) - total_r * total_r

	var discriminant = b*b - 4*a*c
	if discriminant < 0.0:
		return end  # no collision

	discriminant = sqrt(discriminant)

	var t1 = (-b - discriminant) / (2*a)
	var t2 = (-b + discriminant) / (2*a)

	var t = 1.0

	if t1 >= 0.0 and t1 <= 1.0:
		t = min(t, t1)
	if t2 >= 0.0 and t2 <= 1.0:
		t = min(t, t2)

	if t == 1.0:
		return end  # no collision

	var hit_point = start + movement * t
	var normal = (hit_point - center).normalized()
	return hit_point + normal * r


# ------------------------------------------------------------
# SWEPT CIRCLE vs LINE SEGMENT
# ------------------------------------------------------------
func _swept_circle_vs_segment(start: Vector2, end: Vector2, r: float, a: Vector2, b: Vector2) -> Vector2:
	var movement = end - start
	var seg = b - a
	var seg_len = seg.length()

	if seg_len < 0.0001:
		return end

	var seg_dir = seg / seg_len

	# Project start onto segment normal
	var normal = Vector2(-seg_dir.y, seg_dir.x)

	# Distance from start to line
	var dist_start = (start - a).dot(normal)

	# If moving away from wall, skip
	var dist_end = (end - a).dot(normal)
	if abs(dist_start) > r and abs(dist_end) > r:
		return end

	# Solve for intersection time t
	var denom = movement.dot(normal)
	if abs(denom) < 0.0001:
		return end  # parallel

	var t = (r - dist_start) / denom
	if t < 0.0 or t > 1.0:
		return end

	var hit_point = start + movement * t

	# Check if hit point is within segment extents
	var proj = (hit_point - a).dot(seg_dir)
	if proj < 0.0 or proj > seg_len:
		return end

	# Push out
	return hit_point + normal * r
