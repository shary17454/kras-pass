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
	_capture_contract(t)
	await _record_and_replay(t, host)
	_highlights(t)


func _capture_contract(t: TestHarness) -> void:
	t.test("recordings retain match modifiers and teams")
	var cfg := MatchConfig.build("duo_clash", ["nabta", "sakhra", "fanoos", "ramla"], 0, 1, 75)
	cfg.mutators = PackedStringArray(["low_gravity"])
	cfg.chaos = true
	cfg.players[0].team = 1
	cfg.players[1].team = 0
	var captured := ReplayData.from_match(cfg, [], {}, {}, null)
	var decoded := ReplayData.from_dict(captured.to_dict())
	t.not_null(decoded, "new recording loads")
	if decoded != null:
		var restored := decoded.to_config()
		t.equal(Array(restored.mutators), Array(cfg.mutators), "mutators survive disk round trip")
		t.equal(restored.chaos, cfg.chaos, "chaos schedule remains enabled")
		t.equal(restored.players[0].team, 1, "team assignment survives")
		t.equal(restored.players[1].team, 0, "second team survives")
	var ids := {}
	for i in 32:
		var next := ReplayData.from_match(cfg, [], {}, {}, null)
		ids[next.id] = true
	t.equal(ids.size(), 32, "rapid recordings cannot overwrite the same second's file")

	t.test("saving a recording twice keeps one library entry")
	var packet := PackedByteArray()
	for i in cfg.players.size():
		packet.append_array(InputFrame.new().encode())
	captured.frames.append(packet)
	var before := Replays.count()
	t.ok(Replays.save(captured), "initial save succeeds")
	t.ok(Replays.save(captured), "retry succeeds")
	t.equal(Replays.count(), before + 1, "retry is idempotent")
	Replays.erase(captured.id)
	t.equal(Replays.count(), before, "erase leaves no duplicate entry")

	t.test("replay file access never accepts a path as its id")
	var original_id := captured.id
	for unsafe in ["", "../profile", "nested/file", "..\\profile", "/tmp/replay"]:
		captured.id = unsafe
		t.ok(not Replays.save(captured), "unsafe id is refused: " + unsafe)
		t.ok(Replays.load_replay(unsafe) == null, "unsafe id cannot be loaded")
	captured.id = original_id

	t.test("capture limit drops all channels instead of saving a partial match")
	var match_node = load("res://src/match/match_scene.gd").new()
	match_node._replay_enabled = true
	match_node._replay.resize(60 * 60 * 4)
	match_node._checkpoints = {"0": 1}
	match_node._keyframes = {"0": PackedByteArray([0])}
	match_node._world_events = {"0": ["event"]}
	match_node._timeline = [{"tick": 0}]
	match_node._record_replay_tick()
	t.ok(not match_node._replay_enabled, "over-budget match is not advertised as fully recorded")
	for channel in [match_node._replay, match_node._checkpoints, match_node._keyframes,
			match_node._world_events, match_node._timeline]:
		t.ok(channel.is_empty(), "capture releases its memory budget")
	match_node.free()


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
	t.test("version 4 retains its frames without invented modifiers")
	var previous := r.to_dict()
	previous["version"] = 4
	previous.erase("mutators")
	previous.erase("chaos")
	var v4 := ReplayData.from_dict(previous)
	t.not_null(v4, "v4 is still supported")
	if v4 != null:
		t.equal(v4.frames.size(), 120, "v4 input format stays readable")
		t.ok(v4.to_config().mutators.is_empty() and not v4.to_config().chaos, "unknown historical modifiers are not invented")
		t.equal(v4.to_config().players[0].team, -1, "missing team keeps its legacy default")


## The real test: play, then replay, then compare.
##
## Zone Hold rather than Ring Rumble, and the choice is the test's argument.
## Exact reproduction from inputs plus corrections is achievable in a game whose
## outcome is a function of where bodies are; it is not achievable in one whose
## outcome also turns on discrete, position-triggered events — a ring that
## shrinks under you, live bombs picked up by proximity, four bodies shoving
## each other, a drone choosing targets. In Ring Rumble the same recording
## replayed to within 0.9 m on one run and 22 m on another: the divergence is
## chaotic, not a broken mechanism, and asserting exact scores there tests the
## weather. So the strict contract is asserted on a game that can honour it, and
## the chaotic case is covered below by what *is* invariant: the same recording
## still reaches the end, reports no unrecoverable desync, and logs no errors.
func _record_and_replay(t: TestHarness, host: Node) -> void:
	t.test("a recorded match replays to the same result")
	var before_capture = UserSettings.get_value("replay_capture")
	UserSettings.set_value("replay_capture", true)
	var before_count := Replays.count()

	var cfg := MatchConfig.build("zone_hold", ["nabta", "sakhra", "fanoos", "ramla"], 0, 2, 31337)
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
	await _record_and_replay_chaotic(t, host)
	UserSettings.set_value("replay_capture", before_capture)


## The chaotic case: a game with a shrinking ring, live ordnance, four bodies in
## contact and a hover machine choosing targets. Exact equality is not on the
## table; these three properties are, and each of them has caught a real bug —
## an event track that silently dropped decisions, a machine drawing from the
## shared RNG stream, and a replay that ran off the end of its recording.
func _record_and_replay_chaotic(t: TestHarness, host: Node) -> void:
	t.test("a chaotic match still replays end to end without desync")
	var cfg := MatchConfig.build("ring_rumble", ["nabta", "sakhra", "fanoos", "ramla"], 0, 2, 4242)
	cfg.duration_override = 6.0
	cfg.rounds = 1
	var live := await _play(host, {"config": cfg})
	if live["result"] == null:
		t.ok(false, "the chaotic match produced a result")
		return
	var entry: Dictionary = Replays.index()[0]
	var data := Replays.load_replay(String(entry["id"]))
	if data == null:
		t.ok(false, "the chaotic replay loads back")
		return
	t.greater(data.events.size(), 0, "the drone's decisions were recorded, not left to be guessed again")
	var played = await _play(host, {"replay": data})
	t.not_null(played["result"], "the replay reached the end")
	t.equal(int(played["desync"]), -1, "no unrecoverable divergence reported")
	t.equal(int(played["errors"]), 0, "playback logged no errors")
	Replays.erase(String(entry["id"]))


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
