extends Node
## Frame-time probe: four competitors, power-ups on, measured in a real window.
##
## Pass `--all` to sweep every registered minigame instead of the short list.
##
## Sampling only counts frames while the match is live, so a game whose round
## ends early yields fewer than `SAMPLE_FRAMES` samples. That is expected, not a
## reason to keep waiting: `rising_tide` stays live for under two seconds with
## four bots, and an unguarded "wait for 400 live frames" loop simply hangs on
## it forever. Every game therefore also has a wall-clock ceiling, and whatever
## samples exist when the round ends get reported with a note.
const SAMPLE_FRAMES := 400
const WARMUP_FRAMES := 60
const MAX_SECONDS := 25.0

var _scene: Node
var _samples: Array[float] = []
var _frames := 0
var _elapsed := 0.0
var _games := ["ring_rumble", "crate_smash", "goal_guard", "scrap_karts"]
var _index := 0
var _nodes_start := 0

func _ready() -> void:
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
	var cfg := MatchConfig.build(_games[_index], ["nabta","sakhra","barq","turs"], 0, 3, 11)
	cfg.duration_override = 60.0
	_scene = load("res://src/match/match_scene.gd").new()
	add_child(_scene)
	_scene.setup({"config": cfg, "on_finished": func(_r): pass})
	_frames = 0
	_elapsed = 0.0
	_samples.clear()

func _process(delta: float) -> void:
	if _scene == null:
		return
	_elapsed += delta
	var live: bool = _scene.ctx != null and MatchPhase.is_live(_scene.phase)
	if live:
		_frames += 1
		if _frames > WARMUP_FRAMES:
			_samples.append(delta * 1000.0)
	var round_over := _frames > 0 and not live
	if _frames >= SAMPLE_FRAMES or round_over or _elapsed >= MAX_SECONDS:
		await _finish(round_over)

func _finish(round_over: bool) -> void:
	if _samples.is_empty():
		print("%-14s no live frames sampled in %.0fs — round never ran" % [_games[_index], _elapsed])
	else:
		_samples.sort()
		var sum := 0.0
		for s in _samples:
			sum += s
		var mean := sum / _samples.size()
		var note := ""
		if _samples.size() < SAMPLE_FRAMES - WARMUP_FRAMES:
			note = "  (round ended early: %d samples)" % _samples.size() if round_over \
				else "  (timed out: %d samples)" % _samples.size()
		print("%-14s mean %.2f ms (%.0f fps)  p95 %.2f ms  worst %.2f ms  nodes %d  mem %.1f MB%s" % [
			_games[_index], mean, 1000.0 / mean,
			_samples[int(_samples.size() * 0.95)], _samples[_samples.size() - 1],
			get_tree().get_node_count(), OS.get_static_memory_usage() / 1048576.0, note])
	_scene.teardown(); _scene.queue_free(); _scene = null
	_index += 1
	if _index >= _games.size():
		await get_tree().process_frame
		await get_tree().process_frame
		print("nodes after teardown: %d (start %d)" % [get_tree().get_node_count(), _nodes_start])
		get_tree().quit(0)
	else:
		await get_tree().process_frame
		_start()
