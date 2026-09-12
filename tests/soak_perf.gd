extends Node
## Wall-clock frame pacing in a rendered match, including the phone HUD.
## Example: godot --rendering-method mobile --path . tests/soak_perf.tscn -- --seconds=60

var seconds := 60.0
var cap := 60
var quality := 2
var game := "sabaq_sawarikh"
var arena_id := "sky_causeway"
var output := "/tmp/kras-soak.json"
var scene: Node
var samples: Array[float] = []
var cold_samples: Array[float] = []
var distances := [0.0, 0.0, 0.0, 0.0]
var positions: Array[Vector3] = []
var report := {}
var start_us := 0
var last_us := 0
var live_seconds := 0.0
var done := false
var nodes_before := 0
var memory_before := 0.0
var memory_peak := 0.0
var video_peak := 0.0
var draw_peak := 0.0
var primitives_peak := 0.0
var projectile_peak := 0
var process_ms := 0.0
var physics_ms := 0.0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="): seconds = float(arg.get_slice("=", 1))
		if arg.begins_with("--cap="): cap = int(arg.get_slice("=", 1))
		if arg.begins_with("--quality="): quality = int(arg.get_slice("=", 1))
		if arg.begins_with("--game="): game = arg.get_slice("=", 1)
		if arg.begins_with("--arena="): arena_id = arg.get_slice("=", 1)
		if arg.begins_with("--output="): output = arg.get_slice("=", 1)
	UserSettings._values["replay_capture"] = false
	UserSettings._values["graphics_quality"] = quality
	UserSettings._values["fps_limit"] = cap
	UserSettings._apply_engine_settings()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Measure render throughput independently of the connected monitor's refresh.
	Engine.max_fps = cap
	report["display_refresh_hz"] = DisplayServer.screen_get_refresh_rate()
	report["benchmark_cap"] = cap
	Loc.set_locale("ar")
	nodes_before = get_tree().get_node_count()
	memory_before = OS.get_static_memory_usage() / 1048576.0
	var cfg := MatchConfig.build(game, ["fanoos", "mowja", "ramla", "nabta"], 0, 3, 72)
	if not arena_id.is_empty(): cfg.arena_id = arena_id
	cfg.duration_override = seconds + 15.0
	scene = load("res://src/match/match_scene.gd").new()
	add_child(scene)
	var setup_us := Time.get_ticks_usec()
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	report["setup_ms"] = (Time.get_ticks_usec() - setup_us) / 1000.0
	if scene.arena.def.shape == "circuit":
		scene.camera.mode = ArenaCamera.Mode.CHASE
		scene.camera.local_target = scene.ctx.fighter(0)
	# Render identical touch controls without overriding the four active AI inputs.
	var layer := CanvasLayer.new()
	layer.layer = 8
	scene.add_child(layer)
	var touch := TouchSource.new()
	layer.add_child(touch)
	touch.setup(0, Registry.minigame(game))
	touch.set_physics_process(false)
	touch.set_process_input(false)
	for fighter in scene.ctx.fighters:
		positions.append(fighter.global_position)
	start_us = Time.get_ticks_usec()
	last_us = start_us
	print("SOAK_START ", game, " / ", cfg.arena_id, " cap=", cap, " quality=", quality)
	report.merge({"game": game, "arena": cfg.arena_id, "engine": Engine.get_version_info().string,
		"os": OS.get_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"quality": quality, "cap": cap, "render_scale": get_viewport().scaling_3d_scale,
		"output_size": str(get_viewport().get_texture().get_size()), "requested_seconds": seconds})


func _process(_delta: float) -> void:
	if scene == null or done: return
	var now := Time.get_ticks_usec()
	var ms := (now - last_us) / 1000.0
	last_us = now
	var live := scene.ctx != null and MatchPhase.is_live(scene.phase)
	if live:
		live_seconds += ms / 1000.0
		if live_seconds < 3.0:
			cold_samples.append(ms)
		else:
			samples.append(ms)
			process_ms += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			physics_ms += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		memory_peak = maxf(memory_peak, OS.get_static_memory_usage() / 1048576.0)
		video_peak = maxf(video_peak, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)
		draw_peak = maxf(draw_peak, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		primitives_peak = maxf(primitives_peak, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
		if game == "sabaq_sawarikh":
			projectile_peak = maxi(projectile_peak, scene.controller._missiles.size() + scene.controller._bombs.size())
		elif game == "tank_arena":
			projectile_peak = maxi(projectile_peak, scene.controller._shots.size())
		for i in 4:
			var p: Vector3 = scene.ctx.fighter(i).global_position
			distances[i] += p.distance_to(positions[i])
			positions[i] = p
	var elapsed := (now - start_us) / 1000000.0
	if live_seconds >= seconds + 3.0 or (live_seconds > 0 and not live) or elapsed > seconds + 30:
		_finish()


func _stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	values.sort()
	var total := 0.0
	var above_25 := 0
	var above_33 := 0
	var above_50 := 0
	var above_100 := 0
	for ms in values:
		total += ms
		if ms > 25: above_25 += 1
		if ms > 33.34: above_33 += 1
		if ms > 50: above_50 += 1
		if ms > 100: above_100 += 1
	return {"frames": values.size(), "seconds": total / 1000, "mean_ms": total / values.size(),
		"fps": values.size() * 1000 / maxf(total, 0.001), "p95_ms": values[int((values.size() - 1) * 0.95)],
		"p99_ms": values[int((values.size() - 1) * 0.99)], "worst_ms": values.back(),
		"frames_above_25ms": above_25, "frames_above_33ms": above_33,
		"frames_above_50ms": above_50, "frames_above_100ms": above_100}


func _finish() -> void:
	done = true
	set_process(false)
	report["steady"] = _stats(samples)
	report["first_3_seconds"] = _stats(cold_samples)
	report["live_seconds"] = live_seconds
	report["complete_duration"] = live_seconds >= seconds + 3.0
	report["distance_per_player_m"] = distances
	report["static_memory_before_mb"] = memory_before
	report["static_memory_peak_mb"] = memory_peak
	report["render_memory_peak_mb"] = video_peak
	report["peak_draw_calls"] = draw_peak
	report["peak_primitives"] = primitives_peak
	report["peak_active_weapons"] = projectile_peak
	report["process_mean_ms"] = process_ms / maxi(samples.size(), 1)
	report["physics_mean_ms"] = physics_ms / maxi(samples.size(), 1)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.trim_suffix(".json") + ".png")
	scene.teardown()
	scene.queue_free()
	scene = null
	await get_tree().process_frame
	await get_tree().process_frame
	report["nodes_before"] = nodes_before
	report["nodes_after"] = get_tree().get_node_count()
	report["static_memory_after_mb"] = OS.get_static_memory_usage() / 1048576.0
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("SOAK_RESULT ", JSON.stringify(report))
	get_tree().quit(0 if not samples.is_empty() else 1)
