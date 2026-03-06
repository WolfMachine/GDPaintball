# modules/PlayerRegistry.gd
extends Node
class_name PlayerRegistry

const PlayerState = preload("res://state/PlayerState.gd")
const TokenGenerator = preload("res://modules/TokenGenerator.gd")

var token_gen := TokenGenerator.new()

var players := {}            # player_id -> PlayerState
var by_tcp := {}             # tcp_peer_id -> player_id
var by_udp := {}             # udp_peer_id -> player_id
var by_token := {}           # auth_token -> player_id

func create_player(tcp_peer_id: int) -> PlayerState:
	var ps := PlayerState.new()

	var player_id: String = token_gen.generate_player_id()
	var auth_token: String = token_gen.generate_auth_token(player_id)

	ps.id = player_id
	ps.auth_token = auth_token
	ps.client_id = tcp_peer_id
	ps.is_human = true
	ps.status = PlayerState.Status.QUEUED

	players[player_id] = ps
	by_tcp[tcp_peer_id] = player_id
	by_token[auth_token] = player_id

	return ps

func bind_udp(player_id: String, udp_peer_id: int):
	by_udp[udp_peer_id] = player_id
	players[player_id].udp_peer_id = udp_peer_id

func get_by_player_id(player_id: String) -> PlayerState:
	return players.get(player_id, null)

func get_by_tcp(tcp_peer_id: int) -> PlayerState:
	var pid = by_tcp.get(tcp_peer_id, null)
	return players.get(pid, null)

func get_by_udp(udp_peer_id: int) -> PlayerState:
	var pid = by_udp.get(udp_peer_id, null)
	return players.get(pid, null)

func get_by_token(token: String) -> PlayerState:
	var pid = by_token.get(token, null)
	return players.get(pid, null)

func get_all_players() -> Dictionary:
	return players

func remove_player(player_id: String):
	var ps = players.get(player_id, null)
	if ps == null:
		return

	by_tcp.erase(ps.client_id)
	by_udp.erase(ps.udp_peer_id)
	by_token.erase(ps.auth_token)
	players.erase(player_id)
