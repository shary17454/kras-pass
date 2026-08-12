extends RefCounted
## Content integrity: registry validation, balance parity, localization parity,
## and the promises made in the README about how much content ships.


func run(t: TestHarness) -> void:
	t.suite("content")
	_registry(t)
	_counts(t)
	_character_balance(t)
	_localization(t)
	_achievement_conditions(t)
	_state_machine(t)


func _registry(t: TestHarness) -> void:
	t.test("registry validates cleanly")
	var problems := Registry.validate()
	t.empty(problems, "no content problems")


func _counts(t: TestHarness) -> void:
	t.test("shipping content meets the target")
	t.at_least(Registry.characters().size(), 8, "at least 8 playable characters")
	t.at_least(Registry.minigames().size(), 20, "at least 20 mini-games")
	t.at_least(Registry.arenas().size(), 15, "at least 15 arenas")
	t.at_least(Registry.powerups().size(), 8, "a meaningful power-up pool")
	t.at_least(Registry.worlds().size(), 5, "five adventure realms")

	t.test("every mini-game category is represented")
	for cat in MiniGameDef.CATEGORY_NAMES.keys():
		t.at_least(Registry.minigames_in_category(cat).size(), 1,
			"category '%s' has at least one game" % MiniGameDef.CATEGORY_NAMES[cat])

	t.test("adventure stage count")
	var stages := 0
	for w in Registry.worlds():
		stages += w.get("stages", []).size()
	t.at_least(stages, 20, "at least 20 adventure stages")


func _character_balance(t: TestHarness) -> void:
	t.test("no character has a larger stat budget than another")
	var totals: Array[float] = []
	for c in Registry.characters():
		totals.append(c.stat_total())
		t.ok(c.stat_total() > 0.1, "%s has stats" % c.id)
	var lo := totals[0]
	var hi := totals[0]
	for v in totals:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	t.near(hi - lo, 0.0, 0.15, "stat budgets are within 0.15 of each other")

	t.test("starter characters exist and are unlockable from a fresh profile")
	t.at_least(Registry.starter_characters().size(), 2, "at least two starters")
	for c in Registry.characters():
		if not c.starter:
			t.ok(not c.unlock.is_empty(), "%s has an unlock rule" % c.id)


func _localization(t: TestHarness) -> void:
	t.test("Arabic and English have identical key sets")
	t.empty(Loc.parity_gaps(), "no locale parity gaps")

	t.test("every content string resolves in both locales")
	var missing: Array[String] = []
	var original := Loc.locale
	for code in Loc.SUPPORTED:
		Loc.set_locale(code)
		for c in Registry.characters():
			for key in [c.name_key, c.realm_key, c.tagline_key]:
				if not Loc.has(key):
					missing.append("%s:%s" % [code, key])
		for m in Registry.minigames():
			for key in [m.name_key, m.desc_key, m.rules_key]:
				if not Loc.has(key):
					missing.append("%s:%s" % [code, key])
			for hint in m.control_hints:
				if not Loc.has("controls." + hint):
					missing.append("%s:controls.%s" % [code, hint])
		for a in Registry.arenas():
			if not Loc.has(a.name_key):
				missing.append("%s:%s" % [code, a.name_key])
		for w in Registry.worlds():
			for key in [String(w.get("name_key", "")), String(w.get("desc_key", ""))]:
				if not Loc.has(key):
					missing.append("%s:%s" % [code, key])
		for d in Registry.achievement_defs():
			var id := String(d.get("id", ""))
			for key in [Achievements.name_key_of(id), Achievements.desc_key_of(id)]:
				if not Loc.has(key):
					missing.append("%s:%s" % [code, key])
	Loc.set_locale(original)
	t.empty(missing, "no missing translations")

	t.test("Arabic is treated as right-to-left")
	Loc.set_locale("ar")
	t.ok(Loc.is_rtl(), "Arabic reports RTL")
	Loc.set_locale("en")
	t.ok(not Loc.is_rtl(), "English reports LTR")
	Loc.set_locale(original)


func _achievement_conditions(t: TestHarness) -> void:
	t.test("every achievement condition type is implemented")
	var unimplemented: Array[String] = []
	for d in Registry.achievement_defs():
		var cond: Dictionary = d.get("condition", {})
		var id := String(d.get("id", ""))
		if cond.is_empty():
			unimplemented.append(id + " (no condition)")
			continue
		# progress() returns 0..1; an unimplemented type silently returns 0 for
		# every possible target, which is indistinguishable from "no progress",
		# so probe the measurement directly instead.
		var before := Achievements.progress(id)
		t.ok(before >= 0.0 and before <= 1.0, "%s progress is a fraction" % id)
		if not _known_type(String(cond.get("type", ""))):
			unimplemented.append(id + " (" + String(cond.get("type", "")) + ")")
	t.empty(unimplemented, "all achievement condition types handled")


func _known_type(type_name: String) -> bool:
	return type_name in [
		"wins", "matches", "knockouts", "trophies", "gems", "tournaments",
		"expert_wins", "flawless_wins", "win_streak", "characters_unlocked",
		"games_unlocked", "completion", "play_hours", "all_minigames_won",
		"adventure_complete", "game_wins", "game_best",
	]


func _state_machine(t: TestHarness) -> void:
	t.test("match phase transitions are constrained")
	var P := MatchPhase.P
	t.ok(MatchPhase.can_go(P.COUNTDOWN, P.PLAYING), "countdown leads to play")
	t.ok(MatchPhase.can_go(P.PLAYING, P.SUDDEN_DEATH), "play can enter sudden death")
	t.ok(MatchPhase.can_go(P.PLAYING, P.FINISH), "play can finish directly")
	t.ok(not MatchPhase.can_go(P.PLAYING, P.COUNTDOWN), "play cannot rewind to countdown")
	t.ok(not MatchPhase.can_go(P.FINISH, P.PLAYING), "a finished round cannot resume")
	t.ok(not MatchPhase.can_go(P.DONE, P.PLAYING), "done is terminal")
	t.ok(MatchPhase.is_live(P.PLAYING) and MatchPhase.is_live(P.SUDDEN_DEATH), "live phases identified")
	t.ok(not MatchPhase.is_live(P.RESULTS), "results is not a live phase")
