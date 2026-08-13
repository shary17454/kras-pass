extends RefCounted
## PlaylistGenerator and the party-preset path through TournamentSession.
##
## The generator is the thing standing between "random" and "random but never
## annoying" — three push-out games in a row, or the same arena twice back to
## back, are the exact failures these tests pin down.


func run(t: TestHarness) -> void:
	t.suite("playlist & party presets")
	_generate_basics(t)
	_category_variety(t)
	_arena_variety(t)
	_presets_match_data(t)
	_tournament_from_preset(t)


func _pool_of(ids: Array[String]) -> Array[MiniGameDef]:
	var out: Array[MiniGameDef] = []
	for id in ids:
		var def := Registry.minigame(id)
		if def != null:
			out.append(def)
	return out


func _generate_basics(t: TestHarness) -> void:
	t.test("generate() honours the requested count and is seed-stable")
	var pool := Registry.minigames()
	var a := PlaylistGenerator.generate(pool, 12, 777)
	t.equal(a.size(), 12, "exactly the requested number of entries")
	var b := PlaylistGenerator.generate(pool, 12, 777)
	var same := true
	for i in a.size():
		if String(a[i]["game_id"]) != String(b[i]["game_id"]) or String(a[i]["arena_id"]) != String(b[i]["arena_id"]):
			same = false
			break
	t.ok(same, "the same seed reproduces the exact same schedule — a lobby of four devices has to agree")

	t.test("a different seed can produce a different schedule")
	var c := PlaylistGenerator.generate(pool, 12, 778)
	var identical := true
	for i in a.size():
		if String(a[i]["game_id"]) != String(c[i]["game_id"]):
			identical = false
			break
	t.ok(not identical, "seed 777 and 778 do not collide (this would fail on true bad luck, but not on a healthy shuffle)")

	t.test("an empty pool produces an empty schedule, not a crash")
	t.equal(PlaylistGenerator.generate([], 5, 1).size(), 0, "empty in, empty out")


func _category_variety(t: TestHarness) -> void:
	t.test("no two consecutive entries share a category when the pool allows it")
	var pool := Registry.minigames()  # 10 categories represented
	var schedule := PlaylistGenerator.generate(pool, 30, 42)
	var repeats := 0
	for i in range(1, schedule.size()):
		if String(schedule[i]["category"]) == String(schedule[i - 1]["category"]):
			repeats += 1
	# Not a hard zero: once a pass exhausts variety near its tail it is allowed
	# to repeat rather than deadlock, but with 10 categories in the pool this
	# should be rare, not the rule.
	t.ok(repeats <= 3, "category repeats stayed rare over 30 draws (got %d)" % repeats)

	t.test("a single-category pool does not deadlock — it just repeats")
	var narrow := _pool_of(["hurdle_dash", "kart_sprint"])
	var forced := PlaylistGenerator.generate(narrow, 6, 5)
	t.equal(forced.size(), 6, "still produces the full count even though variety is impossible")


func _arena_variety(t: TestHarness) -> void:
	t.test("a game with several arenas avoids repeating the immediately previous one")
	var def := Registry.minigame("ring_rumble")
	t.at_least(def.arena_ids.size(), 2, "ring_rumble has more than one arena to choose from")
	var pool: Array[MiniGameDef] = [def, def, def, def, def, def]
	var schedule := PlaylistGenerator.generate(pool, 8, 3)
	var back_to_back := 0
	for i in range(1, schedule.size()):
		if String(schedule[i]["arena_id"]) == String(schedule[i - 1]["arena_id"]):
			back_to_back += 1
	t.equal(back_to_back, 0, "the same arena never appears twice in a row when an alternative exists")


func _presets_match_data(t: TestHarness) -> void:
	t.test("preset ids come from data, not code")
	var ids := PlaylistGenerator.preset_ids()
	for expected in ["quick", "normal", "long", "chaos", "skill", "races", "survival", "reflex", "family"]:
		t.ok(ids.has(expected), "preset '%s' is registered" % expected)

	t.test("from_preset() honours each preset's own shape")
	var quick := PlaylistGenerator.from_preset("quick", 1)
	t.equal(int(quick["entries"].size()), 5, "quick party is 5 games")
	t.ok(bool(quick["powerups"]), "quick keeps power-ups on")
	t.ok(not bool(quick["chaos"]), "quick is not chaos")

	var chaos := PlaylistGenerator.from_preset("chaos", 1)
	t.equal(int(chaos["entries"].size()), 10, "chaos is 10 games")
	t.ok(bool(chaos["chaos"]), "chaos sets the chaos flag")
	t.ok(PackedStringArray(chaos["mutators"]).has("powerup_rush"), "chaos brings its own mutators")

	var skill := PlaylistGenerator.from_preset("skill", 1)
	t.ok(not bool(skill["powerups"]), "skill turns power-ups off")
	t.equal(int(skill["difficulty"]), PlayerConfig.Difficulty.EXPERT, "skill runs at Expert")

	t.test("a category-filtered preset only draws from its categories")
	var races := PlaylistGenerator.from_preset("races", 1)
	for e in races["entries"]:
		var def := Registry.minigame(String(e["game_id"]))
		t.equal(def.category_name(), "race", "'%s' is a race game, not '%s'" % [def.id, def.category_name()])

	t.test("an unknown preset id degrades to a sane default instead of an empty schedule")
	var unknown := PlaylistGenerator.from_preset("does_not_exist", 1)
	t.at_least(int(unknown["entries"].size()), 1, "still produces something playable")


func _tournament_from_preset(t: TestHarness) -> void:
	t.test("TournamentSession.from_preset() wires games, arenas and modifiers into real configs")
	var players: Array[PlayerConfig] = []
	for i in 4:
		var p := PlayerConfig.new()
		p.slot = i
		p.character_id = Registry.characters()[i].id
		p.is_human = i == 0
		p.ai_difficulty = PlayerConfig.Difficulty.EASY
		players.append(p)

	var session := TournamentSession.from_preset("chaos", players, 555)
	t.equal(session.total_games(), 10, "chaos schedules 10 games")
	t.ok(session.chaos, "the session carries the chaos flag")
	t.ok(PackedStringArray(session.mutators).has("double_hazards"), "and the chaos mutators")

	for p in session.players:
		if not p.is_human:
			t.equal(p.ai_difficulty, PlayerConfig.Difficulty.MEDIUM, "AI slots pick up the preset's difficulty")
		else:
			t.equal(p.ai_difficulty, PlayerConfig.Difficulty.EASY, "the human slot's stored value is left alone")

	var cfg := session.next_config()
	t.not_null(cfg, "a config is produced for the first game")
	if cfg != null:
		var def := Registry.minigame(session.game_ids[0])
		t.ok(def.arena_ids.has(cfg.arena_id), "the pre-picked arena is valid for that game")
		t.equal(str(cfg.mutators), str(session.mutators), "the config carries the session's mutators")
		t.equal(cfg.chaos, session.chaos, "and its chaos flag")

	t.test("a session built the old way (no preset) still works — arena falls back to random")
	var plain := TournamentSession.new()
	plain.setup(players, ["ring_rumble", "crate_smash"] as Array[String], 9)
	var plain_cfg := plain.next_config()
	t.not_null(plain_cfg, "still produces a config")
	t.ok(plain_cfg.arena_id != "", "still picks a valid arena despite no arena_ids being set")
	t.equal(plain_cfg.mutators.size(), 0, "and carries no mutators, since none were set")
