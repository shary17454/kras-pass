extends Node
## Repeated real match lifecycles, with shortened clocks but real race laps.
## Checks ownership after cleanup, not just whether Godot returned exit code 0.

var _rows: Array = []
var _failures: Array[String] = []
var _cycles := 3
var _baseline_nodes := 0
var _baseline_orphans := 0
var _connections := {}
var _release_ui_cache := false
var _release_system_font_cache := false
var _watched_paths := PackedStringArray()
var _human_matrix := false
var _qa_scene: Node
var _qa_pilots: Array[AIBrain] = []
var _qa_ready_tick := 0
const PREPARATION = preload("res://src/match/match_resource_preparation.gd")


func _ready() -> void:
	if not OS.has_feature("editor") or SaveSystem.storage_root == SaveSystem.DIR:
		push_error("Stability QA requires an isolated --test-data-dir")
		get_tree().quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cycles="):
			_cycles = clampi(int(arg.trim_prefix("--cycles=")), 1, 20)
		elif arg == "--profile-idle-ui":
			_release_ui_cache = true
		elif arg == "--profile-system-font-cache":
			_release_system_font_cache = true
		elif arg == "--human-matrix":
			_human_matrix = true
	process_physics_priority = -110
	if _release_system_font_cache and not _release_ui_cache:
		push_error("System font attribution requires --profile-idle-ui after all matches are freed")
		get_tree().quit(1)
		return
	for game in Registry.all_minigames():
		for arena_id in game.arena_ids:
			for path in PREPARATION.paths_for_definitions(game, Registry.arena(arena_id)):
				if not _watched_paths.has(path):
					_watched_paths.append(path)
	SaveSystem.enabled = false
	UserSettings._values["replay_capture"] = false
	UserSettings._values["announcer_enabled"] = false
	await _settle()
	_baseline_nodes = get_tree().get_node_count()
	_baseline_orphans = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_connections = _signal_counts()
	var baseline_memory := _memory_snapshot()
	print("STABILITY BASELINE MEMORY: ", JSON.stringify(baseline_memory))
	var passes: Array = []
	var human_counts: Array[int] = [0]
	if _human_matrix:
		human_counts.assign([0, 1, 2, 3, 4])
	for cycle in _cycles:
		for game in Registry.all_minigames():
			for humans in human_counts:
				var row := await _play(game, cycle, humans)
				_rows.append(row)
				print("STABILITY %d/%d %s humans=%d: %s" % [cycle + 1, _cycles, game.id, humans, "PASS" if row.failures.is_empty() else row.failures])
				for failure in row.failures:
					_failures.append("%d/%s/humans=%d: %s" % [cycle, game.id, humans, failure])
		var snapshot := _memory_snapshot()
		snapshot["cycle"] = cycle
		passes.append(snapshot)
	# First pass warms immutable geometry/audio caches. Later counts should not
	# grow per round; allow small lazy caches, but fail sustained large growth.
	if passes.size() >= 3:
		var growth := int(passes.back().memory_bytes) - int(passes[1].memory_bytes)
		if growth > 16 * 1024 * 1024:
			_failures.append("post-warmup memory growth exceeds 16 MiB")
	var before_release := _memory_snapshot()
	Platform._on_memory_warning()
	await _settle()
	var after_release := _memory_snapshot()
	var release_started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - release_started < 5000:
		await get_tree().process_frame
	var settled_release := _memory_snapshot()
	var ui_release := {}
	var system_font_release := {}
	if _release_ui_cache:
		UIKit.invalidate_theme()
		UIKit._font = null
		UIKit._font_bold = null
		var ui_started := Time.get_ticks_msec()
		while Time.get_ticks_msec() - ui_started < 5000:
			await get_tree().process_frame
		ui_release = _memory_snapshot()
		print("STABILITY IDLE UI RELEASE: ", JSON.stringify(ui_release))
		if _release_system_font_cache:
			# QA-only attribution after match nodes, labels and shared fonts are gone.
			TextServerManager.get_primary_interface().font_clear_system_fallback_cache()
			var system_started := Time.get_ticks_msec()
			while Time.get_ticks_msec() - system_started < 5000:
				await get_tree().process_frame
			system_font_release = _memory_snapshot()
			print("STABILITY SYSTEM FONT RELEASE: ", JSON.stringify(system_font_release))
	if not MeshFactory._mat_cache.is_empty() or not MeshFactory._tex_cache.is_empty() or not MeshFactory._mesh_cache.is_empty():
		_failures.append("graphics caches remain after memory warning")
	print("STABILITY CACHE RELEASE: ", JSON.stringify({"before": before_release, "after": after_release, "settled_5s": settled_release}))
	var report := {"engine": Engine.get_version_info().string, "cycles": _cycles,
		"scope": "39 default arenas, shortened timed rounds; race laps unchanged; not device performance",
		"human_counts": human_counts, "synthetic_touch_pilots": _human_matrix,
		"baseline_nodes": _baseline_nodes, "baseline_orphans": _baseline_orphans,
		"baseline_memory": baseline_memory,
		"cache_release": {"before": before_release, "after": after_release, "settled_5s": settled_release},
		"idle_ui_release": ui_release,
		"system_font_release": system_font_release,
		"passes": passes, "matches": _rows, "failures": _failures}
	var f := FileAccess.open(SaveSystem.storage_root.path_join("stability.json"), FileAccess.WRITE)
	if f == null:
		_failures.append("cannot write report")
	else:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("STABILITY COMPLETE: %d matches, %d failures" % [_rows.size(), _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _memory_snapshot() -> Dictionary:
	var snapshot := {"memory_bytes": OS.get_static_memory_usage(),
		"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
		"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		"materials_cached": MeshFactory._mat_cache.size(),
		"textures_cached": MeshFactory._tex_cache.size(),
		"meshes_cached": MeshFactory._mesh_cache.size()}
	var audio_bytes := 0
	var seen := {}
	for bank in [AudioManager._bank, AudioManager._tracks, AudioManager._ambience_bank]:
		for stream in bank.values():
			if stream is AudioStreamWAV and not seen.has(stream.get_instance_id()):
				seen[stream.get_instance_id()] = true
				audio_bytes += stream.data.size()
	snapshot["audio_pcm_bytes_cached"] = audio_bytes
	var cached := PackedStringArray()
	for path in _watched_paths:
		if ResourceLoader.has_cached(path):
			cached.append(path)
	snapshot["watched_resources_cached"] = cached
	return snapshot


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_qa_scene) or _qa_scene._paused:
		return
	if _qa_scene.phase == MatchPhase.P.INSTRUCTIONS:
		_qa_ready_tick += 1
		for pilot in _qa_pilots:
			InputRouter.push_virtual(pilot.slot, Vector2.ZERO, Vector2.ZERO,
				InputFrame.Btn.ATTACK if _qa_ready_tick % 2 == 0 else 0)
	elif _qa_scene.phase in [MatchPhase.P.PLAYING, MatchPhase.P.SUDDEN_DEATH]:
		for pilot in _qa_pilots:
			pilot.tick(delta)


func _play(game: MiniGameDef, cycle: int, humans := 0) -> Dictionary:
	var failures: Array[String] = []
	var cfg := MatchConfig.build(game.id, ["nabta", "sakhra", "fanoos", "ramla"], humans, 1, 250925 + cycle * 997)
	for player in cfg.players:
		if player.is_human:
			player.device_type = 2
	cfg.rounds = 1
	cfg.duration_override = 5.0
	var scene: Node = load("res://src/match/match_scene.gd").new()
	add_child(scene)
	var captured: Array = []
	var errors := Log.error_count()
	scene.setup({"config": cfg, "on_finished": func(result): captured.append(result)})
	var owned: Array[WeakRef] = [weakref(scene), weakref(scene.ctx), weakref(scene.controller), weakref(scene.mutators)]
	for brain in scene._brains:
		if brain != null:
			owned.append(weakref(brain))
	if scene.touch_sources.size() != humans:
		failures.append("unexpected touch source count")
	# QA pilots publish ordinary frames without changing human configuration or
	# registering as gameplay Bots. This does not exercise physical touch events.
	for source in scene.touch_sources:
		source.set_physics_process(false)
		if InputRouter.source_of(source.slot) != InputRouter.Source.TOUCH:
			failures.append("human input source is not touch")
		var pilot: AIBrain = scene.controller.create_ai(source.slot, 1)
		_qa_pilots.append(pilot)
		owned.append(weakref(pilot))
	_qa_scene = scene
	_qa_ready_tick = 0
	var ticks := 0
	var limit := 60 * (480 if game.id in ["kart_sprint", "sabaq_sawarikh"] else 120)
	while captured.is_empty() and ticks < limit:
		await get_tree().physics_frame
		ticks += 1
		if ticks % 30 == 0:
			for fighter in scene.ctx.fighters:
				if not fighter.global_position.is_finite() or not fighter.velocity.is_finite():
					failures.append("non-finite player state")
					break
		if not failures.is_empty():
			break
	if captured.size() != 1:
		failures.append("missing or repeated match completion")
	else:
		var result: MatchResult = captured[0]
		if result.scores.size() != 4 or result.places.size() != 4 or result.winners().is_empty():
			failures.append("incomplete ranking")
		if not result.finished_naturally or not is_finite(result.duration) or result.duration < 0:
			failures.append("invalid result state")
		for place in result.places:
			if place < 1 or place > 4:
				failures.append("invalid placement")
		owned.append(weakref(result))
	captured.clear()
	var terminal_phase: int = scene.phase
	_qa_scene = null
	_qa_pilots.clear()
	scene.teardown()
	scene.queue_free()
	scene = null
	await _settle()
	for ref in owned:
		if ref.get_ref() != null:
			failures.append("retained match object: " + ref.get_ref().get_class())
	if get_tree().get_node_count() != _baseline_nodes:
		failures.append("scene tree did not return to baseline")
	if int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) != _baseline_orphans:
		failures.append("orphan node count changed")
	if _signal_counts() != _connections:
		failures.append("global signal connections were retained")
	if not Pool.stats().is_empty() or DevTools._active_match != null:
		failures.append("match retained by shared service")
	for slot in 4:
		if InputRouter.source_of(slot) != InputRouter.Source.NONE:
			failures.append("input source retained")
	if Log.error_count() != errors:
		failures.append("runtime error logged")
	return {"game": game.id, "cycle": cycle, "humans": humans, "synthetic_touch_pilots": humans,
		"terminal_phase": MatchPhase.P.keys()[terminal_phase],
		"seed": cfg.seed, "ticks": ticks,
		"memory_bytes": OS.get_static_memory_usage(), "nodes": get_tree().get_node_count(), "failures": failures}


func _settle() -> void:
	for i in 40:
		await get_tree().process_frame


func _signal_counts() -> Dictionary:
	var result := {}
	for service in [EventBus, Platform, UserSettings, get_viewport()]:
		for signal_info in service.get_signal_list():
			var key := str(service.get_instance_id()) + "/" + String(signal_info.name)
			result[key] = service.get_signal_connection_list(signal_info.name).size()
	return result
