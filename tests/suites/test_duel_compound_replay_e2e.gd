extends RefCounted

const SEED := 117
const GUARD_FRAMES := 180 * 60
const POINT_TICK := 30 * 60
const DRIFT_LIMIT := 2.0
const ROSTER := ["sakhra", "turs", "nabta", "ghaim"]
var report := {"seed": SEED, "roster": ROSTER, "ai_count": 4, "difficulty": 2,
	"duration": 110, "duration_override": 0, "guard_sim_seconds": 180,
	"powerups": false, "sudden_death": false, "required_revision": 3,
	"drift_limit_metres": DRIFT_LIMIT, "point_rule": "min(1800, recorded tick count)",
	"injected_positions_health_inputs_keyframes": false}


func run(t: TestHarness, host: Node) -> void:
	t.suite("Duel revision3 natural record disk playback contact seek E2E")
	while Replays._recovery_running:
		await host.get_tree().process_frame
	var root: String = SaveSystem.storage_root
	var cache: Dictionary = SaveSystem._cache.duplicate(true)
	var dirty: Dictionary = SaveSystem._dirty.duplicate(true)
	var read_only: Dictionary = SaveSystem._read_only_paths.duplicate(true)
	var index: Array = Replays._index.duplicate(true)
	var settings: Dictionary = UserSettings._values.duplicate(true)
	var enabled: bool = SaveSystem.enabled
	var depth: int = SaveSystem._batch_depth
	var autosave: float = SaveSystem._autosave_accum
	var audio: bool = AudioManager.enabled
	var freeze: bool = DevTools.freeze_timer
	var forced_ai: int = DevTools.forced_ai_difficulty
	var fixture_root := root.path_join("duel_revision3_e2e_" + Crypto.new().generate_random_bytes(16).hex_encode())
	t.equal(DirAccess.make_dir_recursive_absolute(fixture_root.path_join("replays")), OK, "unique isolated disk root created")
	SaveSystem.storage_root = fixture_root
	SaveSystem._cache = {SaveSystem.PROFILE: {"schema": SaveSystem.SCHEMA_VERSION}}
	SaveSystem._dirty = {}
	SaveSystem._read_only_paths = {}
	SaveSystem._batch_depth = 0
	SaveSystem.enabled = true
	Replays._index = []
	AudioManager.enabled = false
	DevTools.freeze_timer = false
	DevTools.forced_ai_difficulty = -1
	UserSettings.set_value("replay_capture", true)
	var failed_before := t.failed
	var errors_before := Log.error_count()
	await _exercise(t, host)
	t.equal(Log.error_count(), errors_before, "E2E records no runtime errors")
	report["failed_assertions"] = t.failed - failed_before
	report["fixture_root"] = fixture_root
	# Restore settings against the private root before restoring outer objects.
	UserSettings.set_value("replay_capture", settings.get("replay_capture", true))
	UserSettings._values = settings
	AudioManager.enabled = audio
	DevTools.freeze_timer = freeze
	DevTools.forced_ai_difficulty = forced_ai
	SaveSystem.storage_root = root
	SaveSystem._cache = cache
	SaveSystem._dirty = dirty
	SaveSystem._read_only_paths = read_only
	SaveSystem._batch_depth = depth
	SaveSystem._autosave_accum = autosave
	SaveSystem.enabled = enabled
	Replays._index = index
	t.equal(SaveSystem.storage_root, root, "outer storage root restored")
	t.equal(SaveSystem._cache, cache, "outer cache restored")
	t.equal(SaveSystem._dirty, dirty, "outer dirty state restored")
	t.equal(SaveSystem._read_only_paths, read_only, "outer read-only paths restored")
	t.equal(Replays._index, index, "outer replay index restored without erasing fixtures")
	t.equal(UserSettings._values, settings, "all user settings restored")
	t.equal(SaveSystem._batch_depth, depth, "outer save batching restored")
	t.equal(SaveSystem.enabled, enabled, "outer save enabled flag restored")
	t.equal(AudioManager.enabled, audio, "audio enabled flag restored")
	t.equal(DevTools.freeze_timer, freeze, "debug clock setting restored")
	t.equal(DevTools.forced_ai_difficulty, forced_ai, "debug AI override restored")
	report["outer_state_restored"] = true
	var file := FileAccess.open(fixture_root.path_join("duel-e2e-observations.json"), FileAccess.WRITE)
	t.ok(file != null, "original observations retained next to actual disk recording")
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	print("DUEL_COMPOUND_REPLAY_E2E=" + JSON.stringify(report))


func _exercise(t: TestHarness, host: Node) -> void:
	t.test("natural four-AI live recording from authored spawn and health")
	var config := MatchConfig.build("duel_pit", ROSTER, 0, 2, SEED)
	config.rounds = 1
	config.allow_powerups = false
	config.sudden_death = false
	t.equal(config.duration_override, 0.0, "duration is not shortened")
	t.equal(config.definition().duration, 110.0, "natural authored Duel window is 110 seconds")
	var live := await _play(t, host, {"config": config}, true)
	report["live"] = _public(live)
	t.not_null(live.result, "real AI match reaches a terminal result within 180 simulated seconds")
	t.greater(live.hit_events.size(), 0, "actual rival contact hit events occurred")
	t.ok(live.max_damage.any(func(value): return float(value) > 0.0), "actual Duel damage accumulated")
	if live.result == null: return
	t.equal(Replays.count(), 1, "match completion automatically saved one isolated recording")
	if Replays.index().is_empty(): return
	var id: String = Replays.index()[0].id
	var replay_path: String = Replays._path(id)
	t.ok(FileAccess.file_exists(replay_path), "real recording committed to disk")
	var replay := Replays.load_replay(id)
	t.not_null(replay, "real disk recording loads")
	if replay == null: return
	report["replay_path"] = replay_path
	report["replay_sha256"] = FileAccess.get_sha256(replay_path)
	report["ticks"] = replay.tick_count()
	report["keyframes"] = replay.keyframes.size()
	report["checkpoints"] = replay.hashes.size()
	report["world_event_ticks"] = replay.events.size()
	t.equal(replay.combat_revision, 3, "disk recording explicitly selects Duel revision3")
	t.equal(replay.tick_count(), live.tick_count, "every actual live tick was recorded")
	t.ok(replay.correctable() and replay.verifiable(), "genuine hybrid correction and checkpoint channels exist")
	t.equal(replay.keyframes, live.keyframes, "disk keyframes match genuine capture bytes exactly")
	_channel_proof(t, replay, live)
	t.equal(replay.scores, live.result.scores, "disk metadata retains actual result scores")
	t.equal(replay.places, live.result.places, "disk metadata retains actual result places")
	var action_packets := 0
	for tick in replay.tick_count():
		var packet: PackedByteArray = replay.frames.packet_at(tick)
		for slot in 4:
			if packet[slot * InputFrame.BYTES + 8] != 0: action_packets += 1
	t.greater(action_packets, 0, "AI generated real recorded action inputs")
	report["recorded_action_packets"] = action_packets
	var point := mini(POINT_TICK, replay.tick_count())
	var first: int = live.first_contact_tick
	var before := maxi(0, first - ReplayData.KEYFRAME_INTERVAL)
	var after := mini(replay.tick_count(), ceili(float(first + 12) / ReplayData.KEYFRAME_INTERVAL) * ReplayData.KEYFRAME_INTERVAL)
	report["comparison_tick"] = point
	report["seek_ticks"] = [before, after]
	t.test("loaded revision3 replay uses recorded inputs and matches live combat state")
	var played := await _play(t, host, {"replay": replay}, false)
	report["playback"] = _public(played)
	t.not_null(played.result, "loaded replay reaches a terminal result within guard")
	if played.result != null:
		t.equal(played.result.scores, live.result.scores, "played result scores match actual live result")
		t.equal(played.result.places, live.result.places, "played result places match actual live result")
	t.equal(played.desync, -1, "hybrid playback has no unrecoverable desync")
	t.ok(played.drift < DRIFT_LIMIT, "predeclared playback drift remains below two metres")
	_compare(t, "fixed checkpoint", live.states.get(str(point), {}), played.states.get(str(point), {}))
	_compare(t, "first-contact aftermath", live.states.get(str(after), {}), played.states.get(str(after), {}))
	_compare(t, "terminal state", live.final_state, played.final_state)
	report["fixed_live"] = live.states.get(str(point), {})
	report["fixed_playback"] = played.states.get(str(point), {})
	report["contact_live"] = live.states.get(str(after), {})
	report["contact_playback"] = played.states.get(str(after), {})
	t.test("seek across actual first contact and backward seeded rebuild")
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"replay": replay})
	scene.set_physics_process(false)
	scene.set_process(false)
	scene.playback_paused = true
	scene.pb_seek(after)
	t.equal(scene.playback_tick, after, "initial seek reaches actual post-contact tick")
	var forward := _snapshot(scene)
	scene.pb_seek(before)
	t.equal(scene.playback_tick, before, "backward seek rebuilds before first contact")
	var rewind := _snapshot(scene)
	for fighter in scene.ctx.fighters: _profile(t, fighter)
	scene.pb_seek(after)
	t.equal(scene.playback_tick, after, "forward seek crosses same recorded contact again")
	var crossed := _snapshot(scene)
	_compare(t, "seek before contact versus live", live.states.get(str(before), {}), rewind)
	_compare(t, "seek after contact versus live", live.states.get(str(after), {}), crossed)
	_compare(t, "repeated forward seek", forward, crossed)
	t.equal(scene.desync_tick, -1, "seek has no unrecoverable desync")
	t.ok(scene.playback_drift < DRIFT_LIMIT, "seek uses the same predeclared two-metre drift bound")
	report["seek"] = {"forward": forward, "rewind": rewind, "crossed": crossed,
		"desync": scene.desync_tick, "drift": scene.playback_drift}
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame


func _play(t: TestHarness, host: Node, args: Dictionary, live: bool) -> Dictionary:
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	var finished: Array = []
	var launch := args.duplicate()
	launch["on_finished"] = func(result): finished.append(result)
	scene.setup(launch)
	scene.finished.connect(func(result):
		if finished.is_empty(): finished.append(result))
	var initial := _snapshot(scene)
	t.equal(initial.health, [100.0, 100.0, 100.0, 100.0], "actual authored health is 100 at spawn")
	t.equal(initial.damage, [0.0, 0.0, 0.0, 0.0], "actual initial damage is zero")
	t.equal(initial.stocks, [3, 3, 3, 3], "actual controller starts with three stocks")
	var spawns: Array = []
	var calibration: Array = []
	for slot in 4:
		var fighter: Fighter = scene.ctx.fighter(slot)
		spawns.append(fighter.global_position)
		calibration.append(_profile(t, fighter))
		t.equal(scene._brains[slot] != null, live, "only recording runs the four actual AI brains")
	var hits: Array = []
	var swings: Array = []
	var on_hit := func(by: int, victim: int, push: float):
		if by < 0 or by >= 4 or victim < 0 or victim >= 4 or by == victim: return
		var body: Fighter = scene.ctx.fighter(victim)
		hits.append({"tick": scene._tick_index, "by": by, "victim": victim, "push": push,
			"damage": body.damage_percent, "profile": body._duel_compound_budget_enabled})
	EventBus.player_hit.connect(on_hit)
	for fighter in scene.ctx.fighters:
		fighter.attacked.connect(func(slot: int): swings.append({"tick": scene._tick_index, "slot": slot}))
	var states: Dictionary = {"0": initial}
	var maximum: Array = [0.0, 0.0, 0.0, 0.0]
	var frames := 0
	while finished.is_empty() and frames < GUARD_FRAMES:
		await host.get_tree().physics_frame
		frames += 1
		var tick: int = scene._tick_index
		if not states.has(str(tick)):
			var state := _snapshot(scene)
			states[str(tick)] = state
			for slot in 4: maximum[slot] = maxf(float(maximum[slot]), float(state.damage[slot]))
	EventBus.player_hit.disconnect(on_hit)
	var result: MatchResult = finished[0] if not finished.is_empty() else null
	var out := {"result": result, "initial_state": initial, "spawns": spawns, "calibration": calibration,
		"final_state": _snapshot(scene), "states": states, "hit_events": hits, "swings": swings,
		"max_damage": maximum, "first_contact_tick": int(hits[0].tick) if not hits.is_empty() else -1,
		"tick_count": scene._tick_index, "physics_frames": frames, "desync": scene.desync_tick,
		"drift": scene.playback_drift, "keyframes": scene._keyframes.duplicate(true),
		"world_events": scene._world_events.duplicate(true)}
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
	return out


func _channel_proof(t: TestHarness, replay: ReplayData, live: Dictionary) -> void:
	t.equal(replay.events, live.world_events, "disk event channel exactly matches actual live capture")
	var damage_events := 0
	var off_keyframe_events := 0
	for tick in replay.events:
		for event in replay.events[tick]:
			if event is Dictionary and event.get("kind") == "duel_damage":
				damage_events += 1
				if not replay.keyframes.has(str(tick)): off_keyframe_events += 1
	t.equal(off_keyframe_events, 0, "damage channel has no unrecorded/off-keyframe corrections")
	var exact_events := 0
	var observed_matches := 0
	var observed_ticks := 0
	for tick in replay.keyframes:
		var events: Array = replay.events.get(str(tick), [])
		var corrections: Array = events.filter(func(event): return event is Dictionary and event.get("kind") == "duel_damage")
		t.equal(corrections.size(), 1, "keyframe %s has exactly one actual damage event" % tick)
		if corrections.size() != 1: continue
		var event: Dictionary = corrections[0]
		var exact := event.size() == 2 and event.has("kind") and event.has("damage")
		t.ok(exact, "keyframe %s damage event has only the exact kind/damage fields" % tick)
		if exact: exact_events += 1
		var observed: Dictionary = live.states.get(str(tick), {})
		t.ok(not observed.is_empty(), "keyframe %s has a genuine post-tick live observation" % tick)
		if observed.is_empty(): continue
		observed_ticks += 1
		t.equal(event.get("damage"), observed.damage, "keyframe %s disk damage equals observed live damage in every phase" % tick)
		if event.get("damage") == observed.damage: observed_matches += 1
	t.equal(damage_events, replay.keyframes.size(), "one and only one damage snapshot per genuine recorded keyframe")
	report["channel_proof"] = {"disk_equals_live_capture": replay.events == live.world_events,
		"keyframe_count": replay.keyframes.size(), "damage_event_count": damage_events,
		"exact_event_count": exact_events, "observed_tick_count": observed_ticks,
		"observed_damage_match_count": observed_matches, "off_keyframe_count": off_keyframe_events}


func _profile(t: TestHarness, fighter: Fighter) -> Dictionary:
	var tuning: Dictionary = fighter._tuning
	var power := float(tuning.power_base) + float(tuning.power_range) * fighter.data.power
	var resist := (float(tuning.resist_base) + float(tuning.resist_range) * fighter.data.weight) * fighter.data.perk_factor("resistance")
	var neutral_power := float(tuning.power_base) + float(tuning.power_range) * 0.5
	var neutral_resist := float(tuning.resist_base) + float(tuning.resist_range) * 0.5
	var budget := (power / neutral_power) * pow(resist / neutral_resist, 3.0)
	var factor := pow(clampf(budget, 0.85, 1.15) / budget, 0.25)
	t.ok(fighter._duel_compound_budget_enabled, "spawn/rebuilt revision3 enables actual compound profile")
	t.near(fighter.knock_power, power * factor, 0.00000001, "live outgoing profile matches authored post-perk calibration")
	t.near(fighter.knock_resist, resist * factor, 0.00000001, "live resistance matches authored post-perk calibration")
	return {"character": fighter.data.id, "power": fighter.knock_power, "resist": fighter.knock_resist,
		"raw_power": power, "raw_resist": resist, "factor": factor}


func _snapshot(scene: Node) -> Dictionary:
	var stocks: Array = []
	var damage: Array = []
	var health: Array = []
	var body_alive: Array = []
	var profile: Array = []
	for slot in 4:
		var fighter: Fighter = scene.ctx.fighter(slot)
		stocks.append(scene.controller.lives(slot))
		damage.append(fighter.damage_percent)
		health.append(fighter.health)
		body_alive.append(fighter.alive)
		profile.append(fighter._duel_compound_budget_enabled)
	var scores: Array[int] = scene.controller.compute_scores()
	return {"scores": scores.duplicate(), "places": MatchResult.compute_places(scores),
		"ctx_scores": Array(scene.ctx.scores).duplicate(), "alive": Array(scene.ctx.alive).duplicate(),
		"fighter_alive": body_alive, "stocks": stocks, "damage": damage, "health": health, "profile": profile}


func _compare(t: TestHarness, label: String, expected: Dictionary, actual: Dictionary) -> void:
	t.ok(not expected.is_empty() and not actual.is_empty(), label + " contains real observed states")
	if expected.is_empty() or actual.is_empty(): return
	for key in ["scores", "places", "ctx_scores", "alive", "fighter_alive", "stocks", "profile"]:
		t.equal(actual[key], expected[key], label + " preserves " + key)
	for slot in 4:
		t.near(float(actual.damage[slot]), float(expected.damage[slot]), 0.00001, label + " damage slot %d" % slot)
		t.near(float(actual.health[slot]), float(expected.health[slot]), 0.00001, label + " health slot %d" % slot)


func _public(session: Dictionary) -> Dictionary:
	var out := session.duplicate()
	out.erase("states")
	out.erase("keyframes")
	out.erase("world_events")
	out["hit_event_count"] = session.hit_events.size()
	out["swing_count"] = session.swings.size()
	out.erase("hit_events")
	out.erase("swings")
	var result: MatchResult = session.result
	out["result"] = {"scores": result.scores, "places": result.places, "duration": result.duration} if result != null else null
	return out
