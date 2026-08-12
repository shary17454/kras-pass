extends Node
## Frame-time probe: four competitors, power-ups on, measured in a real window.
var _scene: Node
var _samples: Array[float] = []
var _frames := 0
var _games := ["ring_rumble", "crate_smash", "goal_guard", "scrap_karts"]
var _index := 0
var _nodes_start := 0

func _ready() -> void:
	_nodes_start = get_tree().get_node_count()
	_start()

func _start() -> void:
	var cfg := MatchConfig.build(_games[_index], ["nabta","sakhra","barq","turs"], 0, 3, 11)
	cfg.duration_override = 60.0
	_scene = load("res://src/match/match_scene.gd").new()
	add_child(_scene)
	_scene.setup({"config": cfg, "on_finished": func(_r): pass})
	_frames = 0
	_samples.clear()

func _process(delta: float) -> void:
	if _scene == null or _scene.ctx == null or not MatchPhase.is_live(_scene.phase):
		return
	_frames += 1
	if _frames > 60:
		_samples.append(delta * 1000.0)
	if _frames >= 400:
		_samples.sort()
		var sum := 0.0
		for s in _samples:
			sum += s
		var mean := sum / _samples.size()
		print("%-14s mean %.2f ms (%.0f fps)  p95 %.2f ms  worst %.2f ms  nodes %d  mem %.1f MB" % [
			_games[_index], mean, 1000.0 / mean,
			_samples[int(_samples.size() * 0.95)], _samples[_samples.size() - 1],
			get_tree().get_node_count(), OS.get_static_memory_usage() / 1048576.0])
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
