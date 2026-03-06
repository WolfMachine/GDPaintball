class_name PlayerState
extends Resource

# ------------------------------------
# Status Enum
# ------------------------------------
enum Status {
	QUEUED,
	LOADED,
	READY,
	ACTIVE,
	DISCONNECTED
}

var status: Status = Status.QUEUED

# ------------------------------------
# Identity
# ------------------------------------
var id: String = ""          # UUID player_id
var client_id: int = -1      # TCP peer ID
var udp_peer_id: int = -1    # UDP peer ID
var is_human: bool = false
var auth_token: String = ""  # SHA-256 session token
var username: String = ""    # Provided by client

# ------------------------------------
# Team / Match Info
# ------------------------------------
var team: int = 0
var kills: int = 0
var assists: int = 0
var deaths: int = 0

# ------------------------------------
# Core Gameplay State
# ------------------------------------
var position: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var heading: float = 0.0
var health: int = 100

# ------------------------------------
# Player Stats (authoritative)
# ------------------------------------
var speed: float = 200.0
var projectile_damage: int = 20
var power: float = 300.0
var collider_radius: float = 16.0

# ------------------------------------
# Input Intent
# ------------------------------------
var move_input: Vector2 = Vector2.ZERO
var fire_request: bool = false

func is_alive() -> bool:
	return health > 0
