class_name ProjectileState
extends Resource

# ------------------------------------
# Identity
# ------------------------------------
var owner_id: String = ""
var team: int = 0

# ------------------------------------
# Line Geometry
# ------------------------------------
var origin: Vector2 = Vector2.ZERO
var direction: Vector2 = Vector2.UP
var power: float = 0.0

# ------------------------------------
# Projectile Stats (immutable after spawn)
# ------------------------------------
var damage: int = 0

# ------------------------------------
# Stepping State
# ------------------------------------
var traveled: float = 0.0
var tick_counter: int = 0
var alive: bool = true

func is_finished() -> bool:
	return traveled >= power or not alive
