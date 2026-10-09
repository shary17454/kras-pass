extends RefCounted


class InvalidTeamController extends Node:
	func team_of(slot: int) -> int:
		return slot % 2

	func team_score(_team: int):
		return 1.5


func run(t: TestHarness) -> void:
	_evidence_policy(t)
	t.suite("balance simulator policy")
	var sim = load("res://tools/balance_sim.gd").new()
	_arguments(t, sim)
	_balanced_rosters(t, sim)
	t.test("team draw diagnostics distinguish a shared team win from a competitive draw")
	var duo = load("res://src/minigames/duo_clash.gd").new()
	duo._team_score.assign([4, 2])
	var team_outcome: Dictionary = sim._team_outcome(duo, 4)
	t.equal(team_outcome.get("scores"), {0: 4, 1: 2}, "diagnostic retains authoritative shared totals")
	t.equal(team_outcome.get("winners"), [0], "two winning partners represent one winning team")
	t.equal(team_outcome.get("draw"), false, "partner co-winners do not imply opposing-team draw")
	var shared := MatchResult.make("duo_clash", "sweeper_ring", [40, 20, 40, 20])
	t.ok(shared.is_draw(), "individual co-first evidence is preserved independently")
	duo._team_score.assign([2, 4])
	t.equal(sim._team_outcome(duo, 4).get("winners"), [1], "either opposing side can win without a tie")
	duo._team_score.assign([4, 4])
	t.equal(sim._team_outcome(duo, 4).get("draw"), true, "equal opposing totals remain a real team draw")
	t.equal(sim._team_outcome(duo, 1), {}, "missing opposing team cannot be certified")
	var invalid_controller := InvalidTeamController.new()
	t.equal(sim._team_outcome(invalid_controller, 4), {}, "invalid fractional score cannot masquerade as a verified outcome")
	invalid_controller.free()
	var unsupported := Node.new()
	t.equal(sim._team_outcome(unsupported, 4), {}, "unsupported controller retains unknown rather than false success")
	unsupported.free()
	duo.free()
	for unsafe in ["", ".", "relative-save", "user://", "user://simulation", "res://build/save", "/", "C:/"]:
		t.ok(not sim._storage_is_isolated(unsafe), "simulator rejects a non-isolated save directory")
	var player_directory := OS.get_user_data_dir()
	for unsafe in [player_directory, player_directory + "/", player_directory.path_join("simulation"), player_directory.path_join("../" + player_directory.get_file())]:
		t.ok(not sim._storage_is_isolated(unsafe), "absolute player save paths cannot bypass isolation")
	t.ok(sim._storage_is_isolated("/tmp/kras-balance-save"), "explicit external test save is accepted")
	t.ok(sim._storage_is_isolated("/tmp/kras-balance-save/../kras-balance-save-2"), "external path normalization preserves valid isolation")
	t.ok(sim._storage_is_isolated(player_directory + "-isolated"), "a sibling is not confused with a child of player saves")
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


func _balanced_rosters(t: TestHarness, sim: Node) -> void:
	t.test("balanced roster experiments separate character strength from fixed partners")
	t.ok(sim.has_method("_baseline_roster"), "baseline roster selection has a reproducible explicit policy")
	if not sim.has_method("_baseline_roster"):
		return
	var roster := Registry.characters()
	sim.balanced_rosters = false
	for run in 16:
		var expected: Array[String] = []
		for slot in 4:
			expected.append(roster[(slot + run) % roster.size()].id)
		t.equal(sim._baseline_roster(run), expected, "default campaigns preserve their legacy roster policy")
	sim.balanced_rosters = true
	sim.seed_offset = 5800000
	var counts := {}
	var partners := {}
	for character in roster:
		counts[character.id] = [0, 0, 0, 0]
		partners[character.id] = {}
	for run in 1000:
		var selected: Array = sim._baseline_roster(run)
		t.equal(selected.size(), 4, "balanced match contains exactly four characters")
		t.equal(sim._baseline_roster(run), selected, "roster selection is reproducible without mutable RNG state")
		var unique := {}
		for slot in 4:
			var character: String = selected[slot]
			t.ok(counts.has(character), "balanced match uses an original registered character")
			unique[character] = true
			counts[character][slot] += 1
			partners[character][selected[(slot + 2) % 4]] = true
		t.equal(unique.size(), 4, "one match does not duplicate its character")
	for character in roster:
		t.equal(counts[character.id], [125, 125, 125, 125], "all eight characters appear equally in every seat")
		t.equal(partners[character.id].size(), 7, "all possible partners are exercised instead of a fixed adjacent subset")
	var before: Array = sim._baseline_roster(0)
	sim.seed_offset = 5900000
	t.ok(sim._baseline_roster(0) != before, "independent campaign seeds vary actual roster composition")
	t.ok(not sim._parse_args(PackedStringArray(["--balanced-rosters", "--runs=bad"])), "invalid arguments cannot partially change the experiment policy")
	t.ok(sim.balanced_rosters, "rejected parsing preserves the previous policy")
	sim.balanced_rosters = false
	t.ok(sim._parse_args(PackedStringArray(["--balanced-rosters"])), "balanced roster experiments require an explicit supported option")
	t.ok(sim.balanced_rosters, "the experiment option is applied")
	sim.balanced_rosters = false
	sim.seed_offset = 0


func _arguments(t: TestHarness, sim: Node) -> void:
	t.test("balance arguments reject ambiguous or malformed evidence requests")
	t.equal(sim._parse_args.get_argument_count(), 1, "argument validation accepts an explicit argument vector")
	if sim._parse_args.get_argument_count() != 1:
		return
	var before := [sim.runs, sim.only, sim.out_dir, sim.seed_offset, sim.natural_rounds]
	for invalid in ["--out=/tmp/report", "--runs=abc", "--runs=1", "--runs=2.5", "--runs=10001", "--runs=999999999999999999999", "--only=", "--out-dir=", "--clipped-round", "--seed-offset=-1"]:
		t.ok(not sim._parse_args(PackedStringArray(["--runs=24", "--seed-offset=4200000", invalid])), "invalid argument is rejected before any configuration changes")
		t.equal([sim.runs, sim.only, sim.out_dir, sim.seed_offset, sim.natural_rounds], before, "failed parsing preserves the whole prior configuration")
	t.ok(not sim._parse_args(PackedStringArray(["--runs=24", "--runs=8"])), "duplicate campaign settings are rejected")
	t.ok(sim._parse_args(PackedStringArray(["--runs=24", "--only=blast_ball", "--seed-offset=4200000", "--out-dir=/tmp/report with spaces", "--test-data-dir=/tmp/isolated"])), "production workflow arguments and isolated storage remain supported")
	t.equal([sim.runs, sim.only, sim.out_dir, sim.seed_offset], [24, "blast_ball", "/tmp/report with spaces", 4200000], "valid arguments retain exact campaign identity and output path")
	t.ok(sim._parse_args(PackedStringArray(["--runs=1000", "--clipped-rounds"])), "large balance simulations and explicit smoke mode remain available")
	t.equal(sim.runs, 1000, "requested simulation count is not silently clamped")
	t.ok(not sim.natural_rounds, "smoke mode requires the exact explicit option")
	sim.runs = before[0]
	sim.only = before[1]
	sim.out_dir = before[2]
	sim.seed_offset = before[3]
	sim.natural_rounds = before[4]


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
			t.equal(sample["scores"], Array(local_result.scores), "difficulty sample retains actual scores")
			t.equal(sample["places"], Array(local_result.places), "difficulty sample retains actual ranking")
			t.equal(sample["details"], local_result.details, "difficulty sample retains outcome counters")
			sample["details"][0]["boss_defeats"] = 999
			t.equal(local_result.details[0]["boss_defeats"], 0, "sample diagnostics cannot mutate the original result")
			var missing: Dictionary = sim._difficulty_sample(cfg, null)
			t.equal(missing["boss_outcome"], "unknown", "missing result cannot prove boss objective")
			t.ok(not missing["completed"], "missing match retains completion failure")
			t.ok(not missing.has("scores") and not missing.has("places"), "missing match cannot fabricate scores or places")
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


func _evidence_policy(t: TestHarness) -> void:
	t.suite("Balance evidence source policy")
	var evidence = load("res://tools/balance_evidence.gd")
	var a := "a".repeat(64)
	var b := "b".repeat(64)
	var fingerprint: String = evidence.fingerprint({"a.gd": a, "b.gd": b})
	t.equal(fingerprint, evidence.fingerprint({"b.gd": b, "a.gd": a}), "file ordering does not change source identity")
	t.ok(fingerprint != evidence.fingerprint({"a.gd": b, "b.gd": b}), "changed content changes identity")
	t.ok(fingerprint != evidence.fingerprint({"a.gd": a}), "removed file changes identity")
	t.ok(fingerprint != evidence.fingerprint({"renamed.gd": a, "b.gd": b}), "renamed file changes identity")
	t.equal(evidence.fingerprint({"a.gd": "bad"}), "", "invalid file hash cannot form provenance")
	var report := {"simulation_source_start": fingerprint, "simulation_source_end": fingerprint,
		"engine_version": Engine.get_version_info().string, "sample_mode": "natural"}
	var row := {"sample_mode": "natural", "attempted_runs": 24, "runs": 24,
		"difficulty_attempted": 16, "difficulty_completed": 16,
		"difficulty_pairing": "matched_seed_character", "flags": []}
	t.ok(evidence.problems(report, row, fingerprint).is_empty(), "current completed natural evidence passes minimum source gate")
	t.ok(not evidence.problems({}, {}, fingerprint).is_empty(), "missing evidence cannot look balanced")
	t.ok(not evidence.problems(report, row, b).is_empty(), "old source report is rejected")
	for field in ["simulation_source_start", "simulation_source_end", "engine_version", "sample_mode"]:
		var changed := report.duplicate(true)
		changed[field] = "invalid"
		t.ok(not evidence.problems(changed, row, fingerprint).is_empty(), "reject invalid report " + field)
	for field in ["attempted_runs", "runs", "difficulty_attempted", "difficulty_completed"]:
		for value in [null, "24", true, 0, 15, 23.5, NAN, INF]:
			var changed := row.duplicate(true)
			changed[field] = value
			t.ok(not evidence.problems(report, changed, fingerprint).is_empty(), "reject incomplete or malformed sample count")
	for field in ["sample_mode", "difficulty_pairing", "flags"]:
		var changed := row.duplicate(true)
		changed[field] = "invalid"
		t.ok(not evidence.problems(report, changed, fingerprint).is_empty(), "reject invalid sample " + field)
