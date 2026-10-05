extends RefCounted


func run(t: TestHarness) -> void:
	t.suite("replay payload integrity")
	var replay := ReplayData.new()
	replay.id = "payload_test"
	replay.players = [{"slot": 0, "character": "nabta"}]
	for tick in 3:
		replay.frames.append(InputFrame.new().encode())
	var correction := PackedByteArray()
	correction.resize(ReplayData.KEYFRAME_BYTES_PER_PLAYER)
	replay.keyframes["0"] = correction
	replay.keyframes["2"] = correction
	var valid := replay.to_dict()
	var decoded := ReplayData.from_dict(valid)
	t.not_null(decoded, "complete payload loads")
	if decoded != null:
		t.equal(decoded.frames.size(), 3, "all inputs retained")
		t.equal(decoded.keyframes.size(), 2, "all corrections retained")
	for count in [1, 4]:
		var broken := valid.duplicate(true)
		broken["tick_count"] = count
		t.ok(ReplayData.from_dict(broken) == null, "mismatched input tick count refused")
	var raw := Marshalls.base64_to_raw(valid["frames_b64"])
	var truncated := valid.duplicate(true)
	truncated["frames_b64"] = Marshalls.raw_to_base64(raw.slice(0, raw.size() - 1))
	t.ok(ReplayData.from_dict(truncated) == null, "partial input packet refused")
	var keys := Marshalls.base64_to_raw(valid["keyframes_b64"])
	truncated = valid.duplicate(true)
	truncated["keyframes_b64"] = Marshalls.raw_to_base64(keys.slice(0, keys.size() - 1))
	t.ok(ReplayData.from_dict(truncated) == null, "partial correction packet refused")
	var duplicate := valid.duplicate(true)
	duplicate["keyframe_ticks"] = ["0", "0"]
	t.ok(ReplayData.from_dict(duplicate) == null, "duplicate correction ticks refused")
	var input_only := valid.duplicate(true)
	input_only["keyframes_b64"] = ""
	input_only["keyframe_ticks"] = []
	t.not_null(ReplayData.from_dict(input_only), "input-only recordings remain readable")
	var historical_empty := valid.duplicate(true)
	historical_empty["keyframes_b64"] = ""
	t.not_null(ReplayData.from_dict(historical_empty), "historical empty correction channel remains readable")
	var inferred := valid.duplicate(true)
	inferred.erase("tick_count")
	var inferred_replay := ReplayData.from_dict(inferred)
	t.ok(inferred_replay != null and inferred_replay.frames.size() == 3,
		"legacy inferred input count remains supported")
	for channel in ["frames_b64", "keyframes_b64"]:
		for encoded in ["!bad", "AAAA=", "=AAA", "A===", "AA=A", "AB==", "éAAA"]:
			var broken := valid.duplicate(true)
			broken[channel] = encoded
			t.ok(ReplayData.from_dict(broken) == null, "malformed base64 rejected before decoding: " + channel)
	for version in [1, 2, 3]:
		var old := valid.duplicate(true)
		old["version"] = version
		old["frames_b64"] = Marshalls.raw_to_base64(PackedByteArray([1, 2, 3]))
		var migrated := ReplayData.from_dict(old)
		t.ok(migrated != null and migrated.frames.is_empty() and migrated.keyframes.is_empty(),
			"obsolete packet format follows existing honest-empty migration")
