extends Node
class_name RandomNameGenerator

var adjectives: Array = []
var nouns: Array = []
var loaded := false

func _ready():
	_load_names()

func _load_names():
	var path = "res://names.json"
	if not FileAccess.file_exists(path):
		push_error("RandomNameGenerator: names.json missing at %s" % path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("RandomNameGenerator: failed to open names.json")
		return

	var text := file.get_as_text()
	var data = JSON.parse_string(text)

	if typeof(data) != TYPE_DICTIONARY:
		push_error("RandomNameGenerator: invalid JSON format")
		return

	adjectives = data.get("adjectives", [])
	nouns = data.get("nouns", [])

	if adjectives.is_empty() or nouns.is_empty():
		push_error("RandomNameGenerator: adjective/noun lists empty")
		return

	loaded = true
	print("RandomNameGenerator: loaded %d adjectives, %d nouns"
		% [adjectives.size(), nouns.size()])

func generate() -> String:
	if not loaded:
		return "Player_%d" % randi()

	var adj = adjectives[randi() % adjectives.size()]
	var noun = nouns[randi() % nouns.size()]
	return "%s_%s" % [adj, noun]
