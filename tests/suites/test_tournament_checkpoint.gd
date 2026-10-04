extends RefCounted


func run(t: TestHarness, _host: Node) -> void:
	t.suite("tournament checkpoint integrity")
	var session := TournamentSession.new()
	var roster := MatchConfig.build("ring_rumble", ["nabta", "sakhra", "fanoos", "ramla"], 0, 1, 21).players
	session.setup(roster, ["ring_rumble", "ring_rumble"] as Array[String], 912)
	var valid: Dictionary = JSON.parse_string(JSON.stringify(session.to_dict()))
	t.ok(TournamentSession.restore(valid) != null, "current JSON checkpoint restores")
	for field in ["seed", "chaos", "powerups", "double_final", "preset", "owner", "run_id", "performance", "trailed_last"]:
		var bad := valid.duplicate(true)
		bad[field] = "bad" if field in ["seed", "chaos", "powerups", "double_final", "performance", "trailed_last"] else true
		t.ok(TournamentSession.restore(bad) == null, "malformed optional %s rejected" % field)
	for value in [true, "2", 1.5, null, INF, NAN, {}]:
		var bad := valid.duplicate(true)
		bad["seed"] = value
		t.ok(TournamentSession.restore(bad) == null, "malformed seed cannot change the replay schedule")
	for field in ["slot", "difficulty", "team", "device_type", "device_id"]:
		var bad := valid.duplicate(true)
		bad.players[0][field] = "0"
		t.ok(TournamentSession.restore(bad) == null, "roster %s validated before PlayerConfig conversion" % field)
	for field in ["character", "human", "name", "profile", "palette"]:
		var bad := valid.duplicate(true)
		bad.players[0][field] = "true" if field == "human" else 1
		t.ok(TournamentSession.restore(bad) == null, "roster %s type preserved" % field)
	for value in [true, "1", 1.5, null, INF, NAN, {}]:
		var bad := valid.duplicate(true)
		bad.performance[0] = {"falls": value}
		t.ok(TournamentSession.restore(bad) == null, "corrupt awards are not credited")
	for value in [null, true, "0", 0.5, INF, -1, 4]:
		var bad := valid.duplicate(true)
		bad.trailed_last = [value]
		t.ok(TournamentSession.restore(bad) == null, "corrupt trailing slot rejected")
	for value in ["x", "g".repeat(32), "a".repeat(31)]:
		var bad := valid.duplicate(true)
		bad.run_id = value
		t.ok(TournamentSession.restore(bad) == null, "malformed reward identity rejected")
	for seed in [0, -1, 4294967295, 9007199254740991]:
		var good := valid.duplicate(true)
		good.seed = seed
		var restored := TournamentSession.restore(JSON.parse_string(JSON.stringify(good)))
		t.ok(restored != null, "valid integer seed remains supported through JSON")
		if restored != null:
			t.equal(restored.seed_value, seed if seed != 0 else 1, "seed value survives without truncation")
	var unchanged := valid.duplicate(true)
	TournamentSession.restore(valid)
	t.equal(valid, unchanged, "restoration does not rewrite the source checkpoint")
	var legacy := valid.duplicate(true)
	legacy.version = 1
	for field in ["cups", "scoring_mode", "target_cups", "run_id", "performance", "trailed_last"]:
		legacy.erase(field)
	t.ok(TournamentSession.restore(legacy) != null, "legacy optional fields remain optional")
