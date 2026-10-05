extends RefCounted


func run(t: TestHarness) -> void:
	t.suite("replay schema validation")
	var replay := ReplayData.new()
	replay.id = "schema_test"
	replay.minigame_id = "zone_hold"
	replay.arena_id = "vortex_ring"
	replay.players = [{"slot": 0, "character": "nabta", "human": false}]
	replay.frames.append(InputFrame.new().encode())
	replay.hashes["0"] = 123
	replay.keyframes["0"] = PackedByteArray()
	var valid := replay.to_dict()
	for version in range(1, ReplayData.VERSION + 1):
		var previous := valid.duplicate(true)
		previous["version"] = version
		t.not_null(ReplayData.from_dict(previous), "valid historical version %d survives" % version)
	var json := JSON.new()
	t.equal(json.parse(JSON.stringify(valid)), OK, "fixture survives real JSON encoding")
	t.not_null(ReplayData.from_dict(json.data), "JSON numeric representation remains supported")
	for key in ["id", "engine_build", "minigame_id", "arena_id", "frames_b64", "keyframes_b64",
		"version", "created_at", "seed", "rounds", "tick_rate", "tick_count", "duration",
		"duration_override", "allow_powerups", "sudden_death", "chaos", "rules", "hashes",
		"events", "players", "mutators", "highlights", "scores", "places", "keyframe_ticks"]:
		var broken := valid.duplicate(true)
		broken[key] = null
		t.ok(ReplayData.from_dict(broken) == null, "null field rejected safely: " + key)
	for player in [null, "player", {}, {"slot": 0}, {"slot": 0, "character": []},
		{"slot": 0.5, "character": "nabta"}, {"slot": 4, "character": "nabta"},
		{"slot": 0, "character": "nabta", "difficulty": "expert"}]:
		var broken := valid.duplicate(true)
		broken["players"] = [player]
		t.ok(ReplayData.from_dict(broken) == null, "invalid player metadata is refused")
	var duplicates := valid.duplicate(true)
	duplicates["players"] = [valid["players"][0], valid["players"][0]]
	t.ok(ReplayData.from_dict(duplicates) == null, "duplicate player slots refused")
	for key in ["scores", "places", "keyframe_ticks", "mutators", "highlights"]:
		var broken := valid.duplicate(true)
		broken[key] = [null]
		t.ok(ReplayData.from_dict(broken) == null, "invalid array member refused: " + key)
	for key in ["tick_rate", "rounds", "version"]:
		var broken := valid.duplicate(true)
		broken[key] = 0
		t.ok(ReplayData.from_dict(broken) == null, "zero metadata rejected: " + key)
	var nonfinite := valid.duplicate(true)
	nonfinite["duration"] = INF
	t.ok(ReplayData.from_dict(nonfinite) == null, "nonfinite duration refused")
	for channel in ["hashes", "events"]:
		var broken := valid.duplicate(true)
		broken[channel] = {"0": null}
		t.ok(ReplayData.from_dict(broken) == null, "invalid tick channel refused: " + channel)
	for tick in ["bad", "-1", -1, 0.5]:
		var broken := valid.duplicate(true)
		broken["keyframe_ticks"] = [tick]
		t.ok(ReplayData.from_dict(broken) == null, "invalid keyframe tick refused")
	for highlight in [{}, {"kind": "comeback"}, {"kind": [], "tick": 0},
		{"kind": "comeback", "tick": -1}]:
		var broken := valid.duplicate(true)
		broken["highlights"] = [highlight]
		t.ok(ReplayData.from_dict(broken) == null, "invalid playback marker refused")
	# Exercise the same JSON/disk boundary used by the library, not just Variants.
	var path := Replays._path(replay.id)
	for field in ["players", "scores", "mutators", "events", "keyframe_ticks", "highlights"]:
		var broken := valid.duplicate(true)
		broken[field] = "corrupt"
		var file := FileAccess.open(path, FileAccess.WRITE)
		t.not_null(file, "isolated corrupt fixture can be written")
		if file != null:
			file.store_string(JSON.stringify(broken))
			file.close()
			t.ok(Replays.load_replay(replay.id) == null, "disk reader safely refuses malformed " + field)
	DirAccess.remove_absolute(path)
	t.ok(not FileAccess.file_exists(path), "corrupt disk fixture is cleaned up")
