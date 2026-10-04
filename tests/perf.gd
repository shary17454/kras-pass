extends Node
## Frame-time probe: four competitors, power-ups on, measured in a real window.
##
## Pass `--all` to sweep every registered minigame instead of the short list.
##
## Require actual simulation time as well as rendered samples: uncapped drawing
## can otherwise finish the probe before the competitors leave the start line.
## Short rounds are reported honestly rather than restarted to fill the budget.
## The wall-clock ceiling starts after synchronous scene construction, whose
## cost is reported separately; it cannot interrupt a stalled construction call.
const SAMPLE_FRAMES := 400
const WARMUP_SECONDS := 1.0
const MIN_LIVE_SECONDS := 10.0
const MAX_SECONDS := 25.0

var _scene: Node
var _samples: Array[float] = []
var _frames := 0
var _elapsed := 0.0
var _games := ["ring_rumble", "crate_smash", "goal_guard", "scrap_karts"]
var _index := 0
var _nodes_start := 0
var _started_msec := 0
var _build_msec := 0
var _live_seconds := 0.0
var _initial_positions: Array[Vector3] = []
var _max_displacements: Array[float] = []
var _failed := false

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("The frame-time probe requires a rendered window, not headless simulation")
		get_tree().quit(1)
		return
	# With vsync on, every game on a 120 Hz panel reports 8.33 ms and every game
	# on a 60 Hz one reports 16.67 ms — the probe measures the monitor, not the
	# game, and two runs of the same build disagree because the panel changed
	# refresh rate. Unbinding the frame rate is what makes the numbers mean
	# "what this game costs" and makes them comparable between runs.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var user_args := OS.get_cmdline_user_args()
	if "--all" in user_args:
		_games.clear()
		for def in Registry.minigames():
			_games.append(def.id)
	for arg in user_args:
		# `--games=a,b` isolates specific games, which is how you tell a slow
		# game apart from a game that only looks slow because it ran last.
		if arg.begins_with("--games="):
			_games = Array(arg.split("=")[1].split(","))
	_nodes_start = get_tree().get_node_count()
	_start()

func _start() -> void:
	var build_started := Time.get_ticks_msec()
	var cfg := MatchConfig.build(_games[_index], ["nabta","sakhra","barq","turs"], 0, 3, 11)
	cfg.duration_override = 60.0
	_scene = load("res://src/match/match_scene.gd").new()
	add_child(_scene)
	_scene.setup({"config": cfg, "on_finished": func(_r): pass})
	_build_msec = Time.get_ticks_msec() - build_started
	_started_msec = Time.get_ticks_msec()
	_frames = 0
	_elapsed = 0.0
	_live_seconds = 0.0
	_initial_positions.clear()
	_max_displacements.clear()
	_samples.clear()

func _physics_process(delta: float) -> void:
	if _scene == null or _scene.ctx == null or _scene._paused \
			or not MatchPhase.is_live(_scene.phase):
		return
	_live_seconds += delta
	var fighters: Array = _scene.ctx.fighters
	if _initial_positions.is_empty():
		for fighter in fighters:
			_initial_positions.append(fighter.global_position)
			_max_displacements.append(0.0)
	for i in mini(fighters.size(), _initial_positions.size()):
		_max_displacements[i] = maxf(_max_displacements[i],
			fighters[i].global_position.distance_to(_initial_positions[i]))

func _sample_budget_met() -> bool:
	return _samples.size() >= SAMPLE_FRAMES and _live_seconds >= MIN_LIVE_SECONDS

func _should_finish(round_over: bool) -> bool:
	return _sample_budget_met() or round_over or _elapsed >= MAX_SECONDS

func _process(delta: float) -> void:
	if _scene == null:
		return
	_elapsed = float(Time.get_ticks_msec() - _started_msec) / 1000.0
	var live: bool = _scene.ctx != null and MatchPhase.is_live(_scene.phase)
	if live:
		_frames += 1
		if _live_seconds >= WARMUP_SECONDS:
			_samples.append(delta * 1000.0)
	var round_over := _frames > 0 and not live
	if _should_finish(round_over):
		await _finish(round_over)

func _finish(round_over: bool) -> void:
	set_process(false)
	print("PERF_BUILD=" + JSON.stringify({"game": _games[_index], "milliseconds": _build_msec,
		"wall_seconds": _elapsed, "live_frames": _frames, "samples": _samples.size(),
		"simulation_seconds": _live_seconds, "full_sample_budget": _sample_budget_met(),
		"max_displacement": _max_displacements,
		"display": DisplayServer.get_name(), "engine": Engine.get_version_info().string}))
	if _samples.is_empty():
		_failed = true
		print("%-14s no live frames sampled in %.0fs — round never ran" % [_games[_index], _elapsed])
	else:
		_samples.sort()
		var sum := 0.0
		for s in _samples:
			sum += s
		var mean := sum / _samples.size()
		var note := ""
		if not _sample_budget_met():
			note = "  (round ended early: %d samples)" % _samples.size() if round_over \
				else "  (timed out: %d samples)" % _samples.size()
		print("%-14s mean %.2f ms (%.0f fps)  p95 %.2f ms  worst %.2f ms  nodes %d  mem %.1f MB%s" % [
			_games[_index], mean, 1000.0 / mean,
			_samples[int(_samples.size() * 0.95)], _samples[_samples.size() - 1],
			get_tree().get_node_count(), OS.get_static_memory_usage() / 1048576.0, note])
	if "--screenshots" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/kras-perf-%s.png" % _games[_index])
	_scene.teardown(); _scene.queue_free(); _scene = null
	_index += 1
	if _index >= _games.size():
		AudioManager.shutdown()
		await get_tree().process_frame
		await get_tree().process_frame
		OS.delay_msec(100)
		print("nodes after teardown: %d (start %d)" % [get_tree().get_node_count(), _nodes_start])
		get_tree().quit(1 if _failed else 0)
	else:
		await get_tree().process_frame
		_start()
		set_process(true)
