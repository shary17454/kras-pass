extends RefCounted
## Save/load, corruption recovery, unlock logic and progression accounting.
##
## Runs against a scratch slot so the player's real profile is never touched.

const SLOT := "test_profile"


func run(t: TestHarness) -> void:
	t.suite("save & progression")
	_round_trip(t)
	_corruption(t)
	_unlocks(t)
	_completion(t)
	_settings(t)


func _round_trip(t: TestHarness) -> void:
	t.test("write then read returns identical data")
	SaveSystem.erase(SLOT)
	var data := {"trophies": 7, "list": ["a", "b"], "nested": {"x": 1.5}}
	SaveSystem._cache[SLOT] = data
	SaveSystem.mark_dirty(SLOT)
	SaveSystem.flush()
	var loaded := SaveSystem.load_slot(SLOT)
	t.equal(int(loaded.get("trophies", 0)), 7, "scalar survives the round trip")
	t.equal(loaded.get("list", []).size(), 2, "array survives")
	t.near(float(loaded.get("nested", {}).get("x", 0.0)), 1.5, 0.001, "nested float survives")
	t.equal(int(loaded.get("schema", 0)), SaveSystem.SCHEMA_VERSION, "schema version is stamped")


func _corruption(t: TestHarness) -> void:
	t.test("a truncated save falls back to the backup")
	SaveSystem.erase(SLOT)
	SaveSystem._cache[SLOT] = {"generation": 1}
	SaveSystem.mark_dirty(SLOT)
	SaveSystem.flush()
	SaveSystem._cache[SLOT] = {"generation": 2}
	SaveSystem.mark_dirty(SLOT)
	SaveSystem.flush()   # generation 1 is now the .bak

	var path := "user://%s.json" % SLOT
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{\"checksum\": \"deadbeef\", \"body\": \"{\\\"generation\\\": 99}\"}")
	f.close()
	var recovered := SaveSystem.load_slot(SLOT)
	t.equal(int(recovered.get("generation", -1)), 1,
		"checksum mismatch is rejected and the previous good file is restored")

	t.test("a save with no backup degrades to an empty profile, not a crash")
	SaveSystem.erase(SLOT)
	var g := FileAccess.open(path, FileAccess.WRITE)
	g.store_string("not json at all {{{")
	g.close()
	var fresh := SaveSystem.load_slot(SLOT)
	t.ok(fresh is Dictionary, "returns a usable dictionary")
	t.equal(fresh.get("generation", null), null, "and it is empty rather than garbage")
	SaveSystem.erase(SLOT)


func _unlocks(t: TestHarness) -> void:
	t.test("starter characters are available on a fresh profile")
	Progression.reset_progress()
	for c in Registry.starter_characters():
		t.ok(Progression.is_character_unlocked(c.id), "%s is available at the start" % c.id)

	t.test("trophy thresholds unlock the right characters")
	var locked_before: Array[String] = []
	for c in Registry.characters():
		if not Progression.is_character_unlocked(c.id) and String(c.unlock.get("type", "")) == "trophies":
			locked_before.append(c.id)
	t.greater(locked_before.size(), 0, "some characters are trophy-gated")
	Progression.grant_trophies(100)
	for id in locked_before:
		t.ok(Progression.is_character_unlocked(id), "%s unlocked once the trophy bar is met" % id)

	t.test("mini-games unlock and are never re-announced")
	var count_before := Progression.unlocked_games().size()
	t.at_least(count_before, 1, "at least one game is available with no requirements")
	var first := Registry.minigames()[0]
	t.ok(not Progression.unlock_game(first.id), "unlocking an already-unlocked game is a no-op")

	t.test("adventure records clear state and pay a trophy once")
	Progression.reset_progress()
	var world: Dictionary = Registry.worlds()[0]
	var stage: Dictionary = world["stages"][0]
	var before := Progression.trophies()
	var newly := Progression.record_stage(String(world["id"]), String(stage["id"]), true, 3, 10)
	t.ok(newly, "first clear reports as new")
	t.equal(Progression.trophies(), before + 1, "a trophy is awarded")
	var again := Progression.record_stage(String(world["id"]), String(stage["id"]), true, 3, 12)
	t.ok(not again, "replaying an already-cleared stage is not a new clear")
	t.equal(Progression.trophies(), before + 1, "and pays no second trophy")
	t.equal(int(Progression.stage_record(String(world["id"]), String(stage["id"])).get("best", 0)), 12,
		"but the best score is still updated")

	t.test("stars follow placement")
	t.equal(AdventureSession.stars_for(1, 4), 3, "winning is three stars")
	t.equal(AdventureSession.stars_for(2, 4), 2, "second is two")
	t.equal(AdventureSession.stars_for(4, 4), 1, "finishing at all is one")


func _completion(t: TestHarness) -> void:
	t.test("completion percentage is bounded and monotonic")
	Progression.reset_progress()
	var start := Progression.completion_percent()
	t.ok(start >= 0.0 and start <= 100.0, "starts inside 0..100")
	var world: Dictionary = Registry.worlds()[0]
	for stage in world["stages"]:
		Progression.record_stage(String(world["id"]), String(stage["id"]), true, 3, 1)
	var after := Progression.completion_percent()
	t.greater(after, start, "clearing a realm raises completion")
	t.ok(after <= 100.0, "never exceeds 100%")
	Progression.reset_progress()


func _settings(t: TestHarness) -> void:
	t.test("settings persist and clamp to known keys")
	var before := float(UserSettings.get_value("volume_music"))
	UserSettings.set_value("volume_music", 0.42)
	t.near(float(UserSettings.get_value("volume_music")), 0.42, 0.001, "value is stored")
	UserSettings.set_value("not_a_real_setting", 1)
	t.equal(UserSettings.get_value("not_a_real_setting"), null, "unknown keys are rejected")
	UserSettings.set_value("volume_music", before)

	t.test("tutorial flags are one-shot")
	var id := "__test_tutorial"
	UserSettings.set_value("show_control_hints", true)
	var seen: Dictionary = UserSettings.get_value("tutorials_seen")
	seen.erase(id)
	t.ok(UserSettings.should_show_tutorial(id), "first time shows the card")
	UserSettings.mark_tutorial_seen(id)
	t.ok(not UserSettings.should_show_tutorial(id), "second time does not")
	seen.erase(id)
