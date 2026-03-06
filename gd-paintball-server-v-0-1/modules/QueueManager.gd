extends Node
class_name QueueManager

var queued_players: Array = []

func add_player(player_id: String) -> void:
	if not queued_players.has(player_id):
		queued_players.append(player_id)

func remove_player(player_id: String) -> void:
	queued_players.erase(player_id)

func pop_players(max_count: int) -> Array:
	var selected: Array = []
	while selected.size() < max_count and queued_players.size() > 0:
		selected.append(queued_players.pop_front())
	return selected

func has_enough_players(min_count: int) -> bool:
	return queued_players.size() >= min_count

func return_players(players: Array) -> void:
	for p in players:
		add_player(p)
