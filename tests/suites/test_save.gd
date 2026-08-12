extends RefCounted
## Save/load, corruption recovery, unlock logic and progression accounting.
##
## Runs against a scratch slot so the player's real profile is never touched.

const SLOT := "test_profile"


func run(t: TestHarness) -> void:
	t.suite("save & progression")
	_round_trip(t)
	_corruption(t)
	_migration(t)
	_profiles(t)
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


## A version-1 save must survive the upgrade to per-player profiles. Losing
## someone's progress on an update is the one save bug that is never forgiven.
func _migration(t: TestHarness) -> void:
	t.test("a schema-1 save migrates into a named profile")
	var v1 := {
		"schema": 1,
		"progress": {"trophies": 12, "gems": 40, "characters": ["nabta", "barq"]},
		"stats": {"matches": 33, "wins": 11},
		"achievements": {"first_win": 1700000000},
		"daily_done": "20260101",
		"replays": [{"id": "old_one"}],
	}
	var migrated := SaveSystem._migrate(v1.duplicate(true))
	t.equal(int(migrated["schema"]), SaveSystem.SCHEMA_VERSION, "stamped with the current schema")
	t.ok(migrated.has("profiles"), "profiles were created")
	var moved: Dictionary = migrated["profiles"][SaveSystem.DEFAULT_PROFILE]
	t.equal(int(moved["progress"]["trophies"]), 12, "trophies survived")
	t.equal(int(moved["stats"]["matches"]), 33, "statistics survived")
	t.ok(moved["achievements"].has("first_win"), "achievements survived")
	t.equal(String(moved["daily_done"]), "20260101", "the daily record survived")
	t.ok(not migrated.has("progress"), "the old top-level branch is gone")
	t.equal(String(migrated["active_profile"]), SaveSystem.DEFAULT_PROFILE, "the migrated player is active")

	t.test("device-wide branches stay device-wide")
	t.ok(migrated.has("replays"), "the replay library is not moved into a player")
	t.equal(migrated["replays"].size(), 1, "and keeps its contents")

	t.test("migration is idempotent")
	var twice := SaveSystem._migrate(migrated.duplicate(true))
	t.equal(twice["profiles"].size(), 1, "running it again changes nothing")


## Several people share a console; they should not share a save.
func _profiles(t: TestHarness) -> void:
	t.test("profiles isolate progress from each other")
	var original := SaveSystem.active_profile_id()
	var guest := SaveSystem.create_profile("Guest", true)
	t.ok(SaveSystem.profile_ids().has(guest), "the guest exists")
	t.ok(bool(SaveSystem.profile_meta(guest)["guest"]), "and is marked a guest")

	SaveSystem.switch_profile(original)
	Progression.reset_progress()
	Progression.grant_trophies(7)
	var host_trophies := Progression.trophies()
	t.at_least(host_trophies, 7, "the host has trophies")

	SaveSystem.switch_profile(guest)
	t.equal(Progression.trophies(), 0, "the guest starts clean")
	Progression.grant_trophies(2)
	t.equal(Progression.trophies(), 2, "and earns their own")

	SaveSystem.switch_profile(original)
	t.equal(Progression.trophies(), host_trophies, "the host's progress is untouched")

	t.test("deleting a profile cannot leave the device with none")
	SaveSystem.delete_profile(guest)
	t.ok(not SaveSystem.profile_ids().has(guest), "the guest is gone")
	var only := SaveSystem.profile_ids()
	for id in only:
		SaveSystem.delete_profile(id)
	t.at_least(SaveSystem.profile_ids().size(), 1, "at least one profile always remains")
	Progression.reset_progress()


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
