extends Node2D

# ---------------------------------------------------------
# PlayerState: minimal client-side state, network-ready
# ---------------------------------------------------------
class PlayerState:
	# Identity
	var player_id: String = ""
	var is_local: bool = false
	var username: String = ""

	# Status
	enum Status { QUEUED, LOADED, READY, ACTIVE, DISCONNECTED }
	var status: Status = Status.QUEUED

	# Gameplay
	var team: int = 0
	var kills: int = 0
	var assists: int = 0
	var deaths: int = 0

	# Authoritative state (from server)
	var position: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var heading: float = 0.0
	var health: int = 100
	var alive: bool = true

	# Firing event (server delta)
	var fire_request: bool = false

	func is_alive() -> bool:
		return alive and health > 0


# ---------------------------------------------------------
# Player Node
# ---------------------------------------------------------

var state := PlayerState.new()
var camera: Camera2D

func _ready():
	camera = $Body/Camera2D
	camera.enabled = state.is_local
	add_to_group("players")


# ---------------------------------------------------------
# Called by PlayerManager when server delta says "fired"
# ---------------------------------------------------------
func play_fire_effect() -> void:
	# You can replace this with your real effect
	if has_node("Body/MuzzleFlash"):
		$Body/MuzzleFlash.play()

	# Or spawn a hitscan beam here
	# Or call into a weapon script
	# Or draw a line from position in heading direction
	# This is intentionally simple and non-opinionated


# ---------------------------------------------------------
# Remote players get updated by PlayerManager
# Local players ignore server movement deltas
# ---------------------------------------------------------
func apply_authoritative_state() -> void:
	# Position & rotation are applied in PlayerManager._process()
	# This function is here if you want to expand later
	pass
