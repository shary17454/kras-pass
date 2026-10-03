extends RefCounted


func run(t: TestHarness) -> void:
	t.suite("balance simulator policy")
	var sim = load("res://tools/balance_sim.gd").new()
	t.equal(sim._games().size(), Registry.all_minigames().size(), "default balance sweep includes adventure bosses")
	for def in Registry.all_minigames():
		t.equal(sim._window_for(def), def.duration, "%s uses its natural round window" % def.id)
		var cfg := MatchConfig.build(def.id, ["fanoos", "nabta", "ramla", "sakhra"], 0, 1, 119)
		cfg.duration_override = sim._window_for(def)
		var budget: int = sim._tick_budget(cfg)
		if def.category == MiniGameDef.Category.RACE:
			t.equal(budget, 36000, "%s retains the ten-minute lap finish budget" % def.id)
		else:
			t.ok(budget >= int(ceil((def.duration + 90.0) * 60.0)), "%s budget includes complete round and transitions" % def.id)
	sim.natural_rounds = false
	var boss := Registry.minigame("boss_forge")
	t.equal(sim._window_for(boss), 75.0, "clipped boss window remains available explicitly")
	var def := Registry.minigame("ring_rumble")
	sim.runs = 24
	t.equal(sim._difficulty_runs(), 16, "difficulty sample includes a mirrored pair for all eight characters")
	var characters := {}
	for pair in 8:
		var first: MatchConfig = sim._difficulty_configuration(def, pair * 2)
		var second: MatchConfig = sim._difficulty_configuration(def, pair * 2 + 1)
		t.equal(first.seed, second.seed, "paired difficulty samples share the world seed")
		characters[first.players[0].character_id] = true
		for slot in 4:
			t.equal(first.players[slot].character_id, second.players[slot].character_id, "paired difficulty samples share characters")
			t.equal(first.players[slot].character_id, first.players[0].character_id, "difficulty comparison does not mix character strength")
			t.equal(first.players[slot].ai_difficulty, PlayerConfig.Difficulty.EXPERT if slot < 2 else PlayerConfig.Difficulty.EASY, "first pair orientation")
			t.equal(second.players[slot].ai_difficulty, PlayerConfig.Difficulty.EASY if slot < 2 else PlayerConfig.Difficulty.EXPERT, "mirrored pair orientation")
	t.equal(characters.size(), Registry.characters().size(), "difficulty comparison covers the whole roster")
	for offset in [0, 100000, 1000000000]:
		t.ok(sim._set_seed_offset(str(offset)), "valid campaign seed offset is accepted")
		for pair in 8:
			var first: MatchConfig = sim._difficulty_configuration(def, pair * 2)
			var second: MatchConfig = sim._difficulty_configuration(def, pair * 2 + 1)
			t.equal(first.seed, offset + 4242 + pair * 97, "campaign offset changes the actual comparison seed")
			t.equal(first.seed, second.seed, "offset campaign retains mirrored seed pairing")
		for sample in 24:
			t.equal(sim._baseline_seed(sample), offset + 9001 + sample * 613, "baseline uses the same reproducible campaign offset")
	for valid in ["+00000000000000000000001000000000", "00000000000000000000001000000000"]:
		t.ok(sim._set_seed_offset(valid), "leading zeros do not overflow a valid seed")
		t.equal(sim.seed_offset, 1000000000, "normalized seed retains its numeric identity")
	for invalid in ["", "abc", "1.5", "-1", "1000000001", "999999999999999999999", "-999999999999999999999"]:
		t.ok(not sim._set_seed_offset(invalid), "malformed or out-of-range seed offset is rejected")
		t.equal(sim.seed_offset, 1000000000, "rejected offset does not alter campaign identity")
	sim.seed_offset = 0
	sim.runs = 25
	t.equal(sim._difficulty_runs() % 2, 0, "odd baseline counts cannot produce an unmatched difficulty sample")
	sim.runs = 24
	t.ok(sim._window_for(def) <= 45.0, "explicit smoke mode keeps short ordinary windows")
	var row := {
		"runs": sim.runs, "tie_rate": 0.0, "slot_bias": 0.0,
		"wins_by_slot": [1, 1, 1, 1], "character_buckets": 4,
		"wins_by_character": {"a": 1, "b": 1, "c": 1, "d": 1},
		"character_bias": 0.0, "zero_score_runs": 0, "avg_duration": 20.0,
		"expert_edge": 0.6, "difficulty_attempted": 2, "difficulty_completed": 1,
	}
	var flags: Array = sim._flags(def, row)
	t.ok(flags.has("did not finish 1 difficulty comparison runs"), "missing expert/easy matches cannot look successful")
	t.equal(sim._severity(flags), 2, "incomplete difficulty comparison blocks qualification")
	row.difficulty_completed = 2
	t.ok(sim._flags(def, row).is_empty(), "completed balanced sample has no synthetic warning")
	sim.only = "not_a_registered_game"
	t.equal(sim._games().size(), 0, "unknown game selection is empty rather than all games")
	_boss_outcomes(t, sim)
	var probe := TestHarness.new()
	probe.require_suite_assertions(0)
	t.equal(probe.failed, 1, "an aborted zero-assertion suite cannot pass")
	probe.require_suite_assertions(probe.passed + probe.failed)
	t.equal(probe.failed, 2, "a previous failure cannot hide another empty suite")
	var before := probe.passed + probe.failed
	probe.ok(true, "completed fixture assertion")
	probe.require_suite_assertions(before)
	t.equal(probe.failed, 2, "a completed suite retains its original result")
	sim.free()


func _boss_outcomes(t: TestHarness, sim: Node) -> void:
	t.test("boss completion is not inferred from score or duration")
	t.equal(sim._boss_outcome(null), "unknown", "missing match cannot establish defeat")
	var result := MatchResult.make("boss_colossus", "", [500, 100] as Array[int])
	result.duration = 150.0
	t.equal(sim._boss_outcome(result), "unknown", "positive damage and natural deadline alone prove nothing")
	for slot in result.scores.size():
		result.details[slot] = {"boss_rounds": 1, "boss_defeats": 0}
	t.equal(sim._boss_outcome(result), "survived", "explicit surviving boss is recorded separately")
	var defeated := result.duplicate(true) as MatchResult
	for slot in defeated.scores.size():
		defeated.details[slot]["boss_defeats"] = 1
	t.equal(sim._boss_outcome(defeated), "defeated", "explicit defeat proves the round objective")
	t.equal(sim._boss_outcome(MatchResult.aggregate(result.minigame_id, [result, defeated] as Array[MatchResult])), "survived", "mixed round objectives are not a complete victory")
	t.equal(sim._boss_outcome(MatchResult.aggregate(result.minigame_id, [defeated, defeated] as Array[MatchResult])), "defeated", "complete aggregate retains objective proof")
	defeated.details[1]["boss_defeats"] = 0
	t.equal(sim._boss_outcome(defeated), "unknown", "conflicting player evidence cannot be accepted")
	defeated.details[1]["boss_defeats"] = 2
	t.equal(sim._boss_outcome(defeated), "unknown", "more defeats than played rounds is invalid")
	defeated.details[1]["boss_defeats"] = "1"
	t.equal(sim._boss_outcome(defeated), "unknown", "string counters are not coerced into proof")
	defeated.details[1] = []
	t.equal(sim._boss_outcome(defeated), "unknown", "malformed detail rows are rejected without a runtime error")
	var aggregate := MatchResult.aggregate(result.minigame_id, [result, result] as Array[MatchResult])
	for slot in aggregate.scores.size():
		aggregate.details[slot]["boss_defeats"] = 2
	t.equal(sim._boss_outcome(aggregate), "unknown", "aggregate counters cannot contradict retained round outcomes")
	result.finished_naturally = false
	t.equal(sim._boss_outcome(result), "unknown", "aborted outcome cannot establish objective completion")
	t.equal(sim._severity(["boss outcome evidence incomplete"]), 2, "missing objective proof blocks qualification")
	t.equal(sim._severity(["boss never defeated in baseline sample"]), 1, "zero observed defeats require balance investigation")
	t.equal(sim._severity(["boss difficulty outcome evidence incomplete"]), 2, "missing difficulty objectives block qualification")
	t.equal(sim._severity(["boss smoke outcome evidence incomplete"]), 2, "missing smoke objectives block qualification")
	result.finished_naturally = true
	t.equal(sim._boss_outcome(result, "boss_forge"), "unknown", "another game's result cannot prove the selected objective")
	for boss_id in ["boss_forge", "boss_colossus", "boss_dreadnought", "boss_sovereign"]:
		var def := Registry.minigame(boss_id)
		var local_result := result.duplicate(true) as MatchResult
		local_result.minigame_id = boss_id
		for orientation in 2:
			var cfg: MatchConfig = sim._difficulty_configuration(def, orientation)
			var sample: Dictionary = sim._difficulty_sample(cfg, local_result)
			t.equal(sample["seed"], cfg.seed, "difficulty outcome retains configured world seed")
			t.equal(sample["character"], cfg.players[0].character_id, "difficulty outcome retains character identity")
			t.equal(sample["expert_slots"], [0, 1] if orientation == 0 else [2, 3], "difficulty outcome retains mirrored expert orientation")
			t.equal(sample["boss_outcome"], "survived", "natural deadline is explicitly not boss defeat")
			t.ok(sample["completed"], "natural deadline remains a completed match")
			var missing: Dictionary = sim._difficulty_sample(cfg, null)
			t.equal(missing["boss_outcome"], "unknown", "missing result cannot prove boss objective")
			t.ok(not missing["completed"], "missing match retains completion failure")
	var ordinary: MatchConfig = sim._difficulty_configuration(Registry.minigame("ring_rumble"), 0)
	t.ok(not sim._difficulty_sample(ordinary, result).has("boss_outcome"), "ordinary games do not acquire a fake boss objective")
	var boss_row := {
		"runs": 2, "boss_outcomes": [], "boss_defeated_runs": 2, "boss_unknown_runs": 0,
		"difficulty_attempted": 2, "difficulty_completed": 2,
		"difficulty_samples": [{"boss_outcome": "defeated"}, {"boss_outcome": "survived"}],
		"tie_rate": 0.0, "slot_bias": 0.0, "wins_by_slot": [1, 1, 1, 1],
		"character_buckets": 4, "wins_by_character": {"a": 1, "b": 1, "c": 1, "d": 1},
		"character_bias": 0.0, "zero_score_runs": 0, "avg_duration": 20.0, "expert_edge": 0.6,
	}
	var boss_def := Registry.minigame("boss_forge")
	t.ok(not sim._flags(boss_def, boss_row).has("boss difficulty outcome evidence incomplete"), "known mixed difficulty outcomes are valid evidence")
	for bad_samples in [[], [{"boss_outcome": "defeated"}], [{}, {"boss_outcome": "survived"}],
			[{"boss_outcome": "unknown"}, {"boss_outcome": "survived"}], [null, {"boss_outcome": "survived"}]]:
		boss_row["difficulty_samples"] = bad_samples
		t.ok(sim._flags(boss_def, boss_row).has("boss difficulty outcome evidence incomplete"), "incomplete difficulty outcome cannot appear qualified")
