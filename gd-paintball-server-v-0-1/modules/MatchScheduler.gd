extends Node

class_name MatchScheduler

var interval_seconds := 5
var time_accumulator := 0.0

func should_run(delta: float) -> bool:
	time_accumulator += delta
	if time_accumulator >= interval_seconds:
		time_accumulator = 0.0
		return true
	return false
