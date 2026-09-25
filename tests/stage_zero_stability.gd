extends Node
## Repeated real match lifecycles, with shortened clocks but real race laps.
## Checks ownership after cleanup, not just whether Godot returned exit code 0.

var _rows: Array = []
var _failures: Array[String] = []
var _cycles := 3
var _baseline_nodes := 0
var _baseline_orphans := 0
var _connections := {}


func _ready() -> void:
	if not OS.has_feature("editor") or SaveSystem.storage_root == SaveSystem.DIR:
		push_error("Stability QA requires an isolated --test-data-dir")
		get_tree().quit(1)
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cycles="):
			_cycles = clampi(int(arg.trim_prefix("--cycles=")), 1, 20)
	SaveSystem.enabled = false
	UserSettings._values["replay_capture"] = false
	UserSettings._values["announcer_enabled"] = false
	await _settle()
	_baseline_nodes = get_tree().get_node_count()
	_baseline_orphans = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_connections = _signal_counts()
	var passes: Array = []
	for cycle in _cycles:
		for game in Registry.all_minigames():
			var row := await _play(game, cycle)
			_rows.append(row)
			print("STABILITY %d/%d %s: %s" % [cycle + 1, _cycles, game.id, "PASS" if row.failures.is_empty() else row.failures])
			for failure in row.failures:
				_failures.append("%d/%s: %s" % [cycle, game.id, failure])
		passes.append({"cycle": cycle, "memory_bytes": OS.get_static_memory_usage(),
			"objects": Performance.get_monitor(Performance.OBJECT_COUNT),
			"resources": Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)})
	# First pass warms immutable geometry/audio caches. Later counts should not
	# grow per round; allow small lazy caches, but fail sustained large growth.
	if passes.size() >= 3:
		var growth := int(passes.back().memory_bytes) - int(passes[1].memory_bytes)
		if growth > 16 * 1024 * 1024:
			_failures.append("post-warmup memory growth exceeds 16 MiB")
	var report := {"engine": Engine.get_version_info().string, "cycles": _cycles,
		"scope": "4 AI, 39 default arenas, shortened timed rounds; race laps unchanged; not device performance",
		"baseline_nodes": _baseline_nodes, "baseline_orphans": _baseline_orphans,
		"passes": passes, "matches": _rows, "failures": _failures}
	var f := FileAccess.open(SaveSystem.storage_root.path_join("stability.json"), FileAccess.WRITE)
	if f == null:
		_failures.append("cannot write report")
	else:
		f.store_string(JSON.stringify(report, "  "))
		f.close()
	print("STABILITY COMPLETE: %d matches, %d failures" % [_rows.size(), _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)


func _play(game: MiniGameDef, cycle: int) -> Dictionary:
	var failures: Array[String] = []
	var cfg := MatchConfig.build(game.id, ["nabta", "sakhra", "fanoos", "ramla"], 0, 1, 250925 + cycle * 997)
	cfg.rounds = 1
	cfg.duration_override = 5.0
	var scene: Node = load("res://src/match/match_scene.gd").new()
	add_child(scene)
	var captured: Array = []
	var errors := Log.error_count()
	scene.setup({"config": cfg, "on_finished": func(result): captured.append(result)})
	var owned: Array[WeakRef] = [weakref(scene), weakref(scene.ctx), weakref(scene.controller), weakref(scene.mutators)]
	for brain in scene._brains:
		owned.append(weakref(brain))
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
	return {"game": game.id, "cycle": cycle, "seed": cfg.seed, "ticks": ticks,
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
