extends RefCounted
const Daily = preload("res://src/progression/daily_challenge.gd")


func run(t: TestHarness, _host: Node) -> void:
	t.suite("shared daily challenge and profile records")
	var original := SaveSystem.profile().duplicate(true)
	var original_progress := Progression._p.duplicate(true)
	var first := SaveSystem.create_profile("Daily One")
	var second := SaveSystem.create_profile("Daily Two")
	var setup := Daily.plan("20261009")
	t.equal(JSON.stringify(setup), JSON.stringify(Daily.plan("20261009")), "date has a repeatable setup")
	SaveSystem.switch_profile(first)
	Progression._p["games"] = ["ring_rumble"]
	var newcomer := Daily.plan("20261009")
	SaveSystem.switch_profile(second)
	Progression._p["games"] = Registry.minigames().map(func(game): return game.id)
	t.equal(JSON.stringify(newcomer), JSON.stringify(Daily.plan("20261009")), "unlock inventory and profile cannot alter daily selection")
	var date := Time.get_date_dict_from_system(true)
	t.equal(Daily.today_key(), "%04d%02d%02d" % [date.year, date.month, date.day], "day boundary is explicitly UTC")
	var cfg := Daily.configuration(setup, first)
	t.equal(cfg.seed, setup.seed, "preview seed is the match seed")
	t.equal(cfg.players[0].character_id, setup.character, "human uses the shared selected character")
	t.equal(cfg.players[0].local_profile_id, first, "match remembers the original local profile")
	t.equal(Array(cfg.mutators), Array(setup.mutators), "preview modifiers are applied")
	t.equal(cfg.players.size(), 4, "daily includes one human and three bots")
	for player in cfg.players.slice(1):
		t.ok(not player.is_human, "daily opponents are bots")
		t.equal(player.ai_difficulty, setup.difficulty, "daily opponent tier is shared")
	for day in range(1, 29):
		var candidate := Daily.plan("202611%02d" % day)
		var game := Registry.minigame(candidate.game)
		t.ok(not game.is_boss, "ordinary daily excludes adventure-only boss rounds")
		t.ok(game.arena_ids.has(candidate.arena), "daily selects a registered game arena")
		for modifier in candidate.mutators:
			t.ok(MutatorSystem.available_for(game).has(modifier), "daily modifier is compatible")
			t.ok(Loc.has("mutator.%s" % modifier), "daily modifier has a real label")
		var daily_cfg := Daily.configuration(candidate, first)
		t.ok(daily_cfg.players.size() >= game.min_players and daily_cfg.players.size() <= game.max_players, "shared daily satisfies the player count contract")

	var attempt := Daily.begin_attempt(first, setup)
	t.equal(attempt, 1, "starting a match counts the attempt before completion")
	t.equal(Daily.record(first, setup).attempts, 1, "interrupted attempt remains recorded")
	var result := MatchResult.make(setup.game, setup.arena, [20, 10, 5, 1] as Array[int])
	result.duration = 45.0
	t.ok(Daily.complete_attempt(first, setup, attempt, result), "completed attempt is recorded")
	t.ok(Daily.claimed(first, setup.key), "winner claims this day once")
	t.equal(int(SaveSystem.profile_branch(first, "progress").get("gems", 0)), 12, "reward belongs to original profile, not newly active profile")
	t.equal(int(SaveSystem.profile_branch(second, "progress").get("gems", 0)), 0, "other active player does not receive the reward")
	t.ok(not Daily.complete_attempt(first, setup, attempt, result), "repeated callback does not complete twice")
	var again := Daily.begin_attempt(first, setup)
	t.ok(Daily.complete_attempt(first, setup, again, result), "another real attempt may improve its record")
	t.equal(int(SaveSystem.profile_branch(first, "progress").get("gems", 0)), 12, "another daily win cannot grant the reward again")
	t.equal(Daily.record(first, setup).completed, 2, "completed attempts tracked separately")
	t.equal(Daily.record(first, setup).best_score, 20, "best non-race score retained")
	t.near(float(Daily.record(first, setup).best_time), 45.0, 0.001, "winning completion time retained")

	var legacy := Daily.plan("20261008")
	SaveSystem.profile()["profiles"][second]["daily_done"] = "20261008"
	t.ok(Daily.claimed(second, "20261008"), "legacy string claim is preserved")
	var legacy_attempt := Daily.begin_attempt(second, legacy)
	var legacy_result := MatchResult.make(legacy.game, legacy.arena, [20, 10, 5, 1] as Array[int])
	t.ok(Daily.complete_attempt(second, legacy, legacy_attempt, legacy_result), "legacy daily record can gain new statistics")
	t.equal(int(SaveSystem.profile_branch(second, "progress").get("gems", 0)), 0, "legacy paid day is not paid twice")

	var race_plan := _find_race()
	var race_attempt := Daily.begin_attempt(first, race_plan)
	var race := MatchResult.make(race_plan.game, race_plan.arena, [1234, 1400, 1500, 1600] as Array[int], false)
	race.duration = 40.0
	t.ok(Daily.complete_attempt(first, race_plan, race_attempt, race), "race attempt completes")
	t.near(float(Daily.record(first, race_plan).best_time), 12.34, 0.001, "race time uses player finish centiseconds, not whole match duration")
	var aborted := race.duplicate() as MatchResult
	aborted.finished_naturally = false
	t.ok(not Daily.complete_attempt(first, race_plan, Daily.begin_attempt(first, race_plan), aborted), "aborted match cannot claim reward or set a best score")
	var tie_plan := Daily.plan("20261215")
	var tied := MatchResult.make(tie_plan.game, tie_plan.arena, [10, 10, 5, 1] as Array[int])
	t.ok(Daily.complete_attempt(second, tie_plan, Daily.begin_attempt(second, tie_plan), tied), "draw still counts as a completed attempt")
	t.ok(not Daily.claimed(second, tie_plan.key), "draw is not a daily victory")
	for day in range(1, 29):
		Daily.begin_attempt(first, Daily.plan("202611%02d" % day))
	for day in range(1, 29):
		Daily.begin_attempt(first, Daily.plan("202612%02d" % day))
	t.ok(SaveSystem.profile_branch(first, "daily_done").records.size() <= Daily.HISTORY_LIMIT, "daily record history is bounded")
	_test_corrupt_record(t, first, setup)
	SaveSystem.set_profile(original)
	Progression._p = original_progress


func _test_corrupt_record(t: TestHarness, profile_id: String, setup: Dictionary) -> void:
	var key := Daily._record_key(setup)
	var other := {"attempts": 7, "completed": 5, "last_completed_attempt": 7, "best_score": 99, "best_time": 2.0}
	for malformed in ["broken", [], null, {}, {"attempts": {}, "completed": -4, "last_completed_attempt": [], "best_score": [], "best_time": "bad"}]:
		SaveSystem.set_profile_branch(profile_id, "daily_done", {"key": setup.key,
			"claims": {setup.key: true}, "records": {key: malformed, "other-valid-day": other.duplicate(true)}})
		var stored := SaveSystem.profile_branch(profile_id, "daily_done").duplicate(true)
		var gems := int(SaveSystem.profile_branch(profile_id, "progress").get("gems", 0))
		var visible := Daily.record(profile_id, setup)
		t.equal(SaveSystem.profile_branch(profile_id, "daily_done"), stored, "reading damaged row never rewrites save data")
		t.ok(visible is Dictionary, "malformed daily record remains readable")
		t.ok(visible.get("best_score") == null, "malformed best score is not displayed")
		t.ok(visible.get("best_time") == null, "malformed best time is not displayed")
		t.equal(Daily.begin_attempt(profile_id, setup), 1, "damaged row can start a fresh attempt")
		t.equal(Daily.record(profile_id, setup).attempts, 1, "fresh attempt repairs only the damaged row")
		t.ok(Daily.claimed(profile_id, setup.key), "repair preserves prior reward claim")
		t.equal(SaveSystem.profile_branch(profile_id, "daily_done").records["other-valid-day"], other, "valid unrelated record survives repair")
		var result := MatchResult.make(setup.game, setup.arena, [20, 10, 5, 1] as Array[int])
		t.ok(Daily.complete_attempt(profile_id, setup, 1, result), "repaired row accepts natural completion")
		t.equal(int(SaveSystem.profile_branch(profile_id, "progress").get("gems", 0)), gems, "repair cannot pay a claimed day twice")
		t.ok(not Daily.complete_attempt(profile_id, setup, 1, result), "repaired row rejects duplicate completion")
	for invalid in [-1, 0.5, true, INF, NAN, 2147483648.0]:
		var normalized := Daily._normalized_record({"attempts": invalid, "completed": invalid,
			"last_completed_attempt": invalid, "best_score": invalid})
		t.equal(normalized.attempts, 0, "invalid counter is not coerced into progress")
		t.equal(normalized.completed, 0, "invalid completion count is not accepted")
		t.equal(normalized.last_completed_attempt, 0, "invalid completion receipt is not accepted")
		t.equal(normalized.best_score, null, "invalid best score is not accepted")
	var valid := Daily._normalized_record(other)
	t.equal(valid, other, "normalization preserves valid recorded progress")
	var partial := other.duplicate(true)
	partial.erase("last_completed_attempt")
	partial["future_metadata"] = {"medal": "gold"}
	var repaired := Daily._normalized_record(partial)
	t.equal(repaired.completed, 5, "missing receipt cannot erase valid completion count")
	t.equal(repaired.last_completed_attempt, 5, "missing receipt retains a conservative completed-attempt floor")
	t.equal(repaired.get("future_metadata"), partial.future_metadata, "unknown extension data survives normalization")
	var capped := other.duplicate(true)
	capped.attempts = Daily.MAX_ATTEMPTS
	SaveSystem.set_profile_branch(profile_id, "daily_done", {"records": {key: capped}})
	t.equal(Daily.begin_attempt(profile_id, setup), 0, "counter cannot overflow")
	t.equal(SaveSystem.profile_branch(profile_id, "daily_done").records[key], capped, "overflow refusal leaves saved record intact")


func _find_race() -> Dictionary:
	for month in range(1, 13):
		for day in range(1, 29):
			var candidate := Daily.plan("2027%02d%02d" % [month, day])
			if Registry.minigame(candidate.game).scoring == MiniGameDef.Scoring.RACE_TIME:
				return candidate
	return {}
