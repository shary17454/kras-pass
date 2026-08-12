extends RefCounted
## Record a match, save it, load it back, replay it, and assert the replay
## produces the same match.
##
## This is the test that makes the replay feature honest. It also exercises the
## exact property the future network layer needs: that a match is reproducible
## from a seed plus input frames, with divergence detected rather than hidden.


func run(t: TestHarness, host: Node) -> void:
	t.suite("replay")
	_format(t)
	await _record_and_replay(t, host)
	_highlights(t)


func _format(t: TestHarness) -> void:
	t.test("replay serialises and round-trips")
	var r := ReplayData.new()
	r.id = "unit_test"
	r.minigame_id = "ring_rumble"
	r.arena_id = "vortex_ring"
	r.seed_value = 4242
	r.tick_rate = 60
	r.players = [
		{"slot": 0, "character": "nabta", "name": "A", "human": false, "difficulty": 1},
		{"slot": 1, "character": "sakhra", "name": "B", "human": false, "difficulty": 1},
	]
	for i in 120:
		var packet := PackedByteArray()
		for slot in 2:
			var f := InputFrame.new()
			f.move = Vector2(sin(i * 0.1 + slot), cos(i * 0.07))
			f.bits = InputFrame.Btn.DASH if i % 17 == 0 else 0
			packet.append_array(f.encode())
		r.frames.append(packet)
	r.hashes["30"] = 123456
	r.keyframes["6"] = ReplayData.encode_keyframe([], [] as Array[int], [] as Array[bool])
	r.scores = [3, 1] as Array[int]
	r.places = [1, 2] as Array[int]

	var back := ReplayData.from_dict(r.to_dict())
	t.not_null(back, "a replay survives serialisation")
	if back == null:
		return
	t.equal(back.tick_count(), 120, "every tick survives")
	t.equal(back.seed_value, 4242, "the seed survives — without it nothing reproduces")
	t.equal(back.players.size(), 2, "players survive")
	t.equal(back.checkpoint(30), 123456, "state checkpoints survive")
	t.near(back.length_seconds(), 2.0, 0.01, "duration is derived from the tick count")

	var frames: Array = [InputFrame.new(), InputFrame.new()]
	t.ok(back.apply_tick(0, frames), "a tick decodes")
	t.ok(not back.apply_tick(999, frames), "past the end reports the end")

	t.test("a replay from a newer build is refused rather than misread")
	var future := r.to_dict()
	future["version"] = ReplayData.VERSION + 5
	t.ok(ReplayData.from_dict(future) == null, "refused")

	t.test("recordings without keyframes are marked uncorrectable")
	var no_keys := r.to_dict()
	no_keys["keyframe_ticks"] = []
	no_keys["keyframes_b64"] = ""
	var plain := ReplayData.from_dict(no_keys)
	t.ok(plain != null and not plain.correctable(), "reported as drift-prone rather than silently wrong")

	t.test("version 1 recordings still load, marked unverifiable")
	var old := r.to_dict()
	old["version"] = 1
	var migrated := ReplayData.from_dict(old)
	t.not_null(migrated, "still loads")
	if migrated != null:
		t.ok(not migrated.verifiable(), "but cannot be verified")


## The real test: play, then replay, then compare.
func _record_and_replay(t: TestHarness, host: Node) -> void:
	t.test("a recorded match replays to the same result")
	var before_capture = UserSettings.get_value("replay_capture")
	UserSettings.set_value("replay_capture", true)
	var before_count := Replays.count()

	var cfg := MatchConfig.build("ring_rumble", ["nabta", "sakhra", "fanoos", "ramla"], 0, 2, 31337)
	cfg.duration_override = 6.0
	cfg.rounds = 1
	var live := await _play(host, {"config": cfg})
	t.not_null(live["result"], "the match produced a result")
	if live["result"] == null:
		UserSettings.set_value("replay_capture", before_capture)
		return
	t.equal(Replays.count(), before_count + 1, "the match was saved to the library")

	var entry: Dictionary = Replays.index()[0]
	var data := Replays.load_replay(String(entry["id"]))
	t.not_null(data, "the saved replay loads back")
	if data == null:
		UserSettings.set_value("replay_capture", before_capture)
		return
	t.greater(data.tick_count(), 60, "the recording covers the round")
	t.ok(data.verifiable(), "the recording carries state checkpoints")

	var played = await _play(host, {"replay": data})
	var replayed: MatchResult = played["result"]
	t.not_null(replayed, "the replay reached the end")
	if replayed != null:
		var original: MatchResult = live["result"]
		t.equal(str(replayed.scores), str(original.scores), "same scores")
		t.equal(str(replayed.places), str(original.places), "same placements")
	t.equal(int(played["desync"]), -1, "no unrecoverable divergence reported")
	t.equal(int(played["errors"]), 0, "playback logged no errors")
	# The hybrid contract: inputs drive motion, keyframes bound the error. This
	# is the number that would balloon if the correction stopped working.
	t.ok(float(played["drift"]) < 2.0,
		"positional drift stayed under 2 m between corrections (was %.2f m)" % float(played["drift"]))
	t.ok(data.correctable(), "the recording carries position keyframes")

	Replays.erase(String(entry["id"]))
	UserSettings.set_value("replay_capture", before_capture)


func _play(host: Node, args: Dictionary) -> Dictionary:
	var errors_before := Log.error_count()
	var script: Script = load("res://src/match/match_scene.gd")
	var scene: Node = script.new()
	host.add_child(scene)
	var captured: Array = []
	var merged := args.duplicate()
	merged["on_finished"] = func(r): captured.append(r)
	scene.setup(merged)
	scene.finished.connect(func(r):
		if captured.is_empty():
			captured.append(r))
	var tree := host.get_tree()
	var guard := 0
	while captured.is_empty() and guard < 60 * 90:
		await tree.physics_frame
		guard += 1
	var out := {
		"result": captured[0] if captured.size() > 0 else null,
		"desync": scene.desync_tick,
		"drift": scene.playback_drift,
		"errors": Log.error_count() - errors_before,
	}
	scene.teardown()
	scene.queue_free()
	await tree.process_frame
	return out


func _highlights(t: TestHarness) -> void:
	t.test("highlight detection finds the interesting moments")
	var result := MatchResult.make("ring_rumble", "vortex_ring", [10, 9, 4, 1] as Array[int])
	var timeline := [
		{"tick": 30, "type": "last_place", "slot": 0, "value": 0.0, "other": -1},
		{"tick": 60, "type": "lead", "slot": 1, "value": 0.0, "other": -1},
		{"tick": 120, "type": "eliminated", "slot": 3, "value": 4.0, "other": -1},
		{"tick": 200, "type": "hit", "slot": 0, "value": 44.0, "other": 2},
		{"tick": 5300, "type": "lead", "slot": 0, "value": 0.0, "other": -1},
	]
	var found := ReplayHighlights.detect(timeline, result, 5400, 60)
	var kinds := {}
	for h in found:
		kinds[String(h["kind"])] = true
	t.ok(kinds.has("narrow_win"), "a one-point margin is a photo finish")
	t.ok(kinds.has("comeback"), "the winner having been last is a comeback")
	t.ok(kinds.has("late_swing"), "a lead change in the last seconds is a swing")
	t.ok(kinds.has("early_exit"), "an elimination in the first ten seconds is noted")
	t.ok(kinds.has("big_hit"), "the hardest hit is noted")
	for h in found:
		t.ok(int(h["tick"]) >= 0 and int(h["tick"]) < 5400, "highlight ticks are inside the recording")
	t.ok(found.size() <= 6, "no duplicate kinds")

	t.test("a dull match produces no highlights")
	var dull := MatchResult.make("paint_grid", "paint_grid", [40, 20, 10, 5] as Array[int])
	t.equal(ReplayHighlights.detect([], dull, 4800, 60).size(), 0, "nothing to show")
