extends Node
class_name TokenGenerator

# --------------------------------------------------
# PUBLIC API
# --------------------------------------------------

# Player ID: UUID-like string
func generate_player_id() -> String:
	return _generate_uuid()

# Auth token: SHA-256 of (player_id + timestamp + random)
func generate_auth_token(player_id: String) -> String:
	var seed = player_id + str(Time.get_ticks_msec()) + str(randi())
	return _sha256(seed)


# --------------------------------------------------
# INTERNAL: UUID GENERATOR (STRING)
# --------------------------------------------------
func _generate_uuid() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# 8-4-4-4-12 hex pattern
	var parts: Array[String] = []

	parts.append(_rand_hex(rng, 8))
	parts.append(_rand_hex(rng, 4))
	parts.append(_rand_hex(rng, 4))
	parts.append(_rand_hex(rng, 4))
	parts.append(_rand_hex(rng, 12))

	return "%s-%s-%s-%s-%s" % parts


func _rand_hex(rng: RandomNumberGenerator, length: int) -> String:
	var s := ""
	for i in length:
		var v = rng.randi_range(0, 15)
		s += "0123456789abcdef"[v]
	return s


# --------------------------------------------------
# INTERNAL: SHA-256
# --------------------------------------------------
func _sha256(text: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	var hash: PackedByteArray = ctx.finish()
	return hash.hex_encode()
