class_name Config
extends Resource

# ------------------------------------
# Server Tick / Simulation
# ------------------------------------
const TICK_RATE: float = 60.0
const TICK_DELTA: float = 1.0 / TICK_RATE

# ------------------------------------
# Projectile Stepping Model
# ------------------------------------
# Every projectile line is divided into this many segments.
# segment_length = player.power / PROJECTILE_DIVISOR
const PROJECTILE_DIVISOR: float = 10.0

# How many ticks must pass before a projectile advances by one segment.
# 1 = every tick. Increase to slow projectile stepping.
const SEGMENT_TICKS: int = 1

# Small offset so the projectile line starts outside the player collider.
const MUZZLE_OFFSET: float = 2.0

# ------------------------------------
# Player Defaults (authoritative)
# ------------------------------------
const DEFAULT_HEALTH: int = 100
const DEFAULT_POWER: float = 300.0              # total projectile length
const DEFAULT_COLLIDER_RADIUS: float = 16.0     # server-side collision radius
const DEFAULT_PLAYER_SPEED: float = 200.0       # movement speed
const DEFAULT_PROJECTILE_DAMAGE: int = 20       # damage copied into projectile

# ------------------------------------
# World / Gameplay
# ------------------------------------
const PLAY_AREA_MIN: Vector2 = Vector2(-1000, -1000)
const PLAY_AREA_MAX: Vector2 = Vector2(1000, 1000)
