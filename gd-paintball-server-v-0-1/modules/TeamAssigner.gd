extends Node

class_name TeamAssigner

func assign_teams(player_ids: Array) -> Dictionary:
	var teams := {0: [], 1: []}
	var toggle := 0
	for p in player_ids:
		teams[toggle].append(p)
		toggle = 1 - toggle
	return teams
