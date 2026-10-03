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
	for invalid in ["", "abc", "1.5", "-1", "1000000001", "999999999999999999999"]:
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
	sim.free()
