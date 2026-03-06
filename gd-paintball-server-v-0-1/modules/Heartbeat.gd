extends Node
class_name Heartbeat

signal timed_out(player_id: String)

var last_seen: Dictionary = {}        # player_id -> int (ms)
var timeout_ms: int = 10000           # default 10s
var poll_interval: float = 1.0
var _acc: float = 0.0

func register(player_id: String) -> void:
	if player_id == "":
		return
	last_seen[player_id] = Time.get_ticks_msec()

func touch(player_id: String) -> void:
	if last_seen.has(player_id):
		last_seen[player_id] = Time.get_ticks_msec()

func unregister(player_id: String) -> void:
	if last_seen.has(player_id):
		last_seen.erase(player_id)

func _process(delta: float) -> void:
	_acc += delta
	if _acc < poll_interval:
		return
	_acc = 0.0
	var now: int = Time.get_ticks_msec()
	var to_drop: Array = []
	for pid in last_seen.keys():
		var last: int = int(last_seen[pid])
		if now - last > timeout_ms:
			to_drop.append(pid)
	for pid in to_drop:
		last_seen.erase(pid)
		emit_signal("timed_out", pid)
