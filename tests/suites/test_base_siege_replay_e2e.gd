extends RefCounted

const SEED := 117
const GUARD_TICKS := 180 * 60
const CHECKPOINT_TICK := 30 * 60
const DRIFT_LIMIT := 2.0
var report := {"seed": SEED, "duration": 105, "guard_seconds": 180, "ai_count": 4,
	"ai_difficulty": 2, "duration_override": 0, "powerups": false, "sudden_death": false,
	"positions_or_health_injected": false, "fabricated_keyframes": false,
	"point_rule": "min(1800, recorded tick count)", "drift_limit_metres": DRIFT_LIMIT}


func run(t: TestHarness, host: Node) -> void:
	t.suite("BaseSiege revision two natural record disk playback seek E2E")
	while Replays._recovery_running:
		await host.get_tree().process_frame
	var root: String = SaveSystem.storage_root
	var cache: Dictionary = SaveSystem._cache.duplicate(true)
	var dirty: Dictionary = SaveSystem._dirty.duplicate(true)
	var protected_paths: Dictionary = SaveSystem._read_only_paths.duplicate(true)
	var index: Array = Replays._index.duplicate(true)
	var settings: Dictionary = UserSettings._values.duplicate(true)
	var enabled: bool = SaveSystem.enabled
	var batch_depth: int = SaveSystem._batch_depth
	var autosave: float = SaveSystem._autosave_accum
	var audio: bool = AudioManager.enabled
	var freeze: bool = DevTools.freeze_timer
	var forced_ai: int = DevTools.forced_ai_difficulty
	var fixture_root := root.path_join("base_siege_e2e_" + Crypto.new().generate_random_bytes(16).hex_encode())
	t.equal(DirAccess.make_dir_recursive_absolute(fixture_root.path_join("replays")), OK, "unique isolated replay directory created")
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
	t.equal(Log.error_count(), errors_before, "natural E2E logs no runtime errors")
	report["failed_assertions"] = t.failed - failed_before
	report["fixture_root"] = fixture_root
	# Restore while isolated, then restore every outer persistence object.
	UserSettings.set_value("replay_capture", settings.get("replay_capture", true))
	UserSettings._values = settings
	AudioManager.enabled = audio
	DevTools.freeze_timer = freeze
	DevTools.forced_ai_difficulty = forced_ai
	SaveSystem.storage_root = root
	SaveSystem._cache = cache
	SaveSystem._dirty = dirty
	SaveSystem._read_only_paths = protected_paths
	SaveSystem._batch_depth = batch_depth
	SaveSystem._autosave_accum = autosave
	SaveSystem.enabled = enabled
	Replays._index = index
	t.equal(Replays._index, index, "outer replay index restored without deleting fixtures")
	t.equal(SaveSystem._cache, cache, "outer profile/settings cache restored")
	t.equal(SaveSystem._dirty, dirty, "outer dirty state restored")
	t.equal(UserSettings._values, settings, "all user settings restored")
	report["outer_state_restored"] = true
	var file := FileAccess.open(fixture_root.path_join("e2e-observations.json"), FileAccess.WRITE)
	t.ok(file != null, "E2E observations retained with original recording")
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	print("BASE_SIEGE_REPLAY_E2E=" + JSON.stringify(report))


func _exercise(t: TestHarness, host: Node) -> void:
	t.test("record real seeded AI round from authored spawn and 100 health")
	var cfg := MatchConfig.build("base_siege", ["nabta", "sakhra", "fanoos", "ramla"], 0, 2, SEED)
	cfg.rounds = 1
	cfg.allow_powerups = false
	cfg.sudden_death = false
	t.equal(cfg.duration_override, 0.0, "natural authored duration not overridden")
	t.equal(cfg.definition().duration, 105.0, "fixed case uses natural 105 second window")
	var live := await _play(t, host, {"config": cfg}, true)
	report["live"] = _public_session(live)
	t.not_null(live.result, "real AI round finishes within 180 simulated seconds")
	if live.result == null: return
	t.greater(live.base_hits, 0, "fixed natural round actually exercises base damage")
	report["fatal_e2e_exercised"] = live.base_destroyed > 0
	t.equal(Replays.count(), 1, "automatic match completion saved exactly one isolated replay")
	if Replays.index().is_empty(): return
	var id: String = Replays.index()[0].id
	var replay_path: String = Replays._path(id)
	t.ok(FileAccess.file_exists(replay_path), "recording committed to actual disk")
	var data := Replays.load_replay(id)
	t.not_null(data, "disk recording loads through real library")
	if data == null: return
	report["replay_path"] = replay_path
	report["recording_sha256"] = FileAccess.get_sha256(replay_path)
	report["ticks"] = data.tick_count()
	report["keyframes"] = data.keyframes.size()
	report["checkpoints"] = data.hashes.size()
	t.equal(data.combat_revision, 2, "real saved recording routes atomic BaseSiege")
	t.equal(data.tick_count(), live.tick_count, "all actual live ticks were captured")
	t.ok(data.correctable() and data.verifiable(), "only genuine recorded corrections and hashes used")
	t.equal(data.scores, live.result.scores, "disk result scores equal real live result")
	t.equal(data.places, live.result.places, "disk result places equal real live result")
	t.equal(data.keyframes, live.keyframes, "disk keyframes are byte-identical to live capture, not fabricated")
	var point := mini(CHECKPOINT_TICK, data.tick_count())
	var first_damage: int = live.first_damage_tick
	var before_damage := maxi(0, first_damage - ReplayData.KEYFRAME_INTERVAL)
	var after_damage := mini(data.tick_count(), ceili(float(first_damage + 12) / ReplayData.KEYFRAME_INTERVAL) * ReplayData.KEYFRAME_INTERVAL)
	report["comparison_tick"] = point
	report["seek_before_damage"] = before_damage
	report["seek_after_damage"] = after_damage
	t.test("disk playback from genuine initial conditions matches damage state and result")
	var played := await _play(t, host, {"replay": data}, false)
	report["playback"] = _public_session(played)
	t.not_null(played.result, "disk replay finishes within 180 simulated seconds")
	if played.result != null:
		t.equal(played.result.scores, live.result.scores, "E2E playback result scores match actual recording")
		t.equal(played.result.places, live.result.places, "E2E playback result places match actual recording")
	t.equal(played.desync, -1, "hybrid replay reports no unrecoverable desync")
	t.ok(played.drift < DRIFT_LIMIT, "predeclared hybrid drift stays below two metres")
	_compare(t, "fixed checkpoint", live.states.get(str(point), {}), played.states.get(str(point), {}))
	_compare(t, "after first real damage", live.states.get(str(after_damage), {}), played.states.get(str(after_damage), {}))
	_compare(t, "final live state", live.final_state, played.final_state)
	report["fixed_live"] = live.states.get(str(point), {})
	report["fixed_playback"] = played.states.get(str(point), {})
	report["after_damage_live"] = live.states.get(str(after_damage), {})
	report["after_damage_playback"] = played.states.get(str(after_damage), {})
	t.test("real seek rewinds and crosses recorded damage without fabricated state")
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"replay": data})
	scene.set_physics_process(false)
	scene.set_process(false)
	scene.playback_paused = true
	scene.pb_seek(after_damage)
	t.equal(scene.playback_tick, after_damage, "initial forward seek reaches exact damage target")
	var forward := _snapshot(scene)
	scene.pb_seek(before_damage)
	t.equal(scene.playback_tick, before_damage, "backward seek rebuilds before actual damage")
	var rewound := _snapshot(scene)
	scene.pb_seek(after_damage)
	t.equal(scene.playback_tick, after_damage, "forward seek crosses damage again exactly once")
	var crossed := _snapshot(scene)
	_compare(t, "seek versus live before damage", live.states.get(str(before_damage), {}), rewound)
	_compare(t, "seek versus live after damage", live.states.get(str(after_damage), {}), crossed)
	_compare(t, "repeated seek after damage", forward, crossed)
	t.equal(scene.desync_tick, -1, "seek reports no unrecoverable desync")
	t.ok(scene.playback_drift < DRIFT_LIMIT, "seek honors same predeclared drift bound")
	report["seek"] = {"first_forward": forward, "rewound": rewound, "crossed": crossed,
		"desync": scene.desync_tick, "drift": scene.playback_drift}
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame


func _play(t: TestHarness, host: Node, args: Dictionary, recording: bool) -> Dictionary:
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	var finished: Array = []
	var launch := args.duplicate()
	launch["on_finished"] = func(result): finished.append(result)
	scene.setup(launch)
	scene.finished.connect(func(result):
		if finished.is_empty(): finished.append(result))
	var initial := _snapshot(scene)
	t.equal(initial.health, [100.0, 100.0, 100.0, 100.0], "all bases start at authored health 100")
	t.equal(initial.scores, [0, 0, 0, 0], "fresh match starts with no synthetic credits")
	var spawns: Array = []
	for slot in 4:
		spawns.append(scene.ctx.fighter(slot).global_position)
		if recording:
			t.ok(scene._brains[slot] != null, "all four actual AI brains run only during recording")
		else:
			t.ok(scene._brains[slot] == null, "playback uses recorded inputs, never AI")
	var states: Dictionary = {"0": initial}
	var first_damage := -1
	var guard := 0
	while finished.is_empty() and guard < GUARD_TICKS:
		await host.get_tree().physics_frame
		guard += 1
		var tick: int = scene._tick_index
		if not states.has(str(tick)):
			var state := _snapshot(scene)
			states[str(tick)] = state
			if first_damage < 0 and state.health.any(func(h): return float(h) < 100.0):
				first_damage = tick
	var result: MatchResult = finished[0] if not finished.is_empty() else null
	var hits := 0
	var destroyed := 0
	for details in scene.ctx.details:
		hits += int(details.get("base_hits", 0))
		destroyed += int(details.get("bases_broken", 0))
	var out := {"result": result, "states": states, "first_damage_tick": first_damage,
		"tick_count": scene._tick_index, "physics_frames": guard, "base_hits": hits,
		"base_destroyed": destroyed, "initial_spawns": spawns, "initial_state": initial,
		"final_state": _snapshot(scene), "desync": scene.desync_tick,
		"drift": scene.playback_drift, "keyframes": scene._keyframes.duplicate(true)}
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
	return out


func _snapshot(scene: Node) -> Dictionary:
	var health: Array = []
	var cooldown: Array = []
	var hits: Array = []
	var visible: Array = []
	var layers: Array = []
	var fighter_alive: Array = []
	for slot in 4:
		for base in scene.controller._bases:
			if int(base.slot) != slot: continue
			health.append(base.health)
			cooldown.append(base.cooldown)
			hits.append(base.hits)
			visible.append(base.node.visible)
			layers.append(base.body.collision_layer)
		fighter_alive.append(scene.ctx.fighter(slot).alive)
	var scores: Array[int] = scene.controller.compute_scores()
	return {"scores": scores.duplicate(), "places": MatchResult.compute_places(scores),
		"alive": Array(scene.ctx.alive).duplicate(), "fighter_alive": fighter_alive,
		"health": health, "cooldown": cooldown, "hits": hits, "visible": visible, "collision_layers": layers}


func _compare(t: TestHarness, label: String, expected: Dictionary, actual: Dictionary) -> void:
	t.ok(not expected.is_empty() and not actual.is_empty(), label + " has actual observed snapshots")
	if expected.is_empty() or actual.is_empty(): return
	for key in ["scores", "places", "alive", "fighter_alive", "health", "hits", "visible", "collision_layers"]:
		t.equal(actual[key], expected[key], label + " preserves " + key)
	for slot in 4:
		t.near(float(actual.cooldown[slot]), float(expected.cooldown[slot]), 0.00001, label + " preserves cooldown slot %d" % slot)


func _public_session(session: Dictionary) -> Dictionary:
	var out := session.duplicate()
	out.erase("states")
	out.erase("keyframes")
	var result: MatchResult = session.result
	out["result"] = {"scores": result.scores, "places": result.places, "duration": result.duration} if result != null else null
	return out
