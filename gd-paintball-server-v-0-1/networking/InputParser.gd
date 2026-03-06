class_name InputParser
extends Node

const PlayerState = preload("res://state/PlayerState.gd")

func apply_input_to_player(player_id: String, packet: Dictionary, players: Array) -> void:
	if packet.get("t", 0) != 1:
		return

	var p := _find_player(player_id, players)
	if p == null:
		return

	var vx = packet.get("vx", 0.0)
	var vy = packet.get("vy", 0.0)
	var mv = Vector2(vx, vy)
	p.move_input = mv.normalized() if mv.length() > 0 else Vector2.ZERO

	p.heading = float(packet.get("h", p.heading))

	if packet.get("f", false):
		p.fire_request = true

func _find_player(player_id: String, players: Array) -> PlayerState:
	for p in players:
		if p.id == player_id:
			return p
	return null
