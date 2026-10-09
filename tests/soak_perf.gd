extends Node
## Wall-clock frame pacing in a rendered match, including the phone HUD.
## Example: godot --rendering-method mobile --path . tests/soak_perf.tscn -- --seconds=60

var seconds := 60.0
var cap := 60
var quality := 2
var game := "sabaq_sawarikh"
var arena_id := "sky_causeway"
var output := "/tmp/kras-soak.json"
var humans := 0
var firing := false
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
var viewport_sizes: Array[String] = []
var window_sizes: Array[String] = []
var slow_frames: Array[Dictionary] = []
var trace_started := false
var pipeline_start := {}
var previous_pipelines := {}


func _configuration_error() -> String:
	var definition := Registry.minigame(game)
	if definition == null:
		return "Unknown performance minigame: " + game
	if not arena_id.is_empty() and (Registry.arena(arena_id) == null or not definition.arena_ids.has(arena_id)):
		return "Invalid performance arena for %s: %s" % [game, arena_id]
	if not is_finite(seconds) or seconds <= 0.0:
		return "Performance duration must be finite and positive"
	if cap < 0 or quality < 0 or quality > 3:
		return "Invalid performance frame limit or quality tier"
	if humans < 0 or humans > 4:
		return "Local human view count must be between zero and four"
	if humans > 0 and game not in ["tank_arena", "sabaq_sawarikh"]:
		return "Scripted local driving is only supported by vehicle probes"
	if firing and (game != "tank_arena" or humans == 0):
		return "Scripted firing requires local tank input slots"
	return ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="): seconds = float(arg.get_slice("=", 1))
		if arg.begins_with("--cap="): cap = int(arg.get_slice("=", 1))
		if arg.begins_with("--quality="): quality = int(arg.get_slice("=", 1))
		if arg.begins_with("--game="): game = arg.get_slice("=", 1)
		if arg.begins_with("--arena="): arena_id = arg.get_slice("=", 1)
		if arg.begins_with("--output="): output = arg.get_slice("=", 1)
		if arg.begins_with("--humans="): humans = int(arg.get_slice("=", 1))
		if arg == "--fire": firing = true
	var error := _configuration_error()
	if not error.is_empty():
		push_error(error)
		get_tree().quit(1)
		return
	if DisplayServer.get_name() == "headless":
		push_error("Rendered performance sampling requires a real window")
		get_tree().quit(1)
		return
	UserSettings._values["replay_capture"] = false
	UserSettings._values["graphics_quality"] = quality
	UserSettings._values["fps_limit"] = cap
	if humans > 0:
		UserSettings._values["touch_controls"] = "on"
	UserSettings._apply_engine_settings()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# Measure render throughput independently of the connected monitor's refresh.
	Engine.max_fps = cap
	report["display_refresh_hz"] = DisplayServer.screen_get_refresh_rate()
	report["benchmark_cap"] = cap
	Loc.set_locale("ar")
	nodes_before = get_tree().get_node_count()
	memory_before = OS.get_static_memory_usage() / 1048576.0
	var cfg := MatchConfig.build(game, ["fanoos", "mowja", "ramla", "nabta"], humans, 3, 72)
	for player in cfg.players:
		if player.is_human:
			player.device_type = 2
	if not arena_id.is_empty(): cfg.arena_id = arena_id
	cfg.duration_override = seconds + 15.0
	scene = load("res://src/match/match_scene.gd").new()
	add_child(scene)
	var setup_us := Time.get_ticks_usec()
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	# MatchScene has a production fallback; a benchmark must attest its real map.
	if scene.arena == null or scene.arena.def == null or scene.arena.def.id != cfg.arena_id:
		push_error("Performance scene did not build the requested arena")
		scene.teardown()
		scene.queue_free()
		get_tree().quit(1)
		return
	if game == "tank_arena":
		var cover_points := []
		var cover_digests := []
		for cover: StaticBody3D in scene.controller.world.buildings:
			var collision: CollisionShape3D = cover.get_child(1)
			cover_points.append(collision.shape.points.size())
			cover_digests.append(collision.shape.get_meta("source_digest", "original"))
		report["cover_hull_points"] = cover_points
		report["cover_hull_source_digests"] = cover_digests
	var prepared_states := 0
	for fighter in scene.ctx.fighters:
		if is_instance_valid(fighter._state_fx):
			prepared_states += 1
	report["prepared_state_visuals"] = prepared_states
	var effect_label_pools := []
	for chip in scene.hud._chips:
		effect_label_pools.append(chip.effects.get_child_count())
	report["prepared_effect_labels_per_player"] = effect_label_pools
	report["setup_ms"] = (Time.get_ticks_usec() - setup_us) / 1000.0
	if scene.arena.def.shape == "circuit" and scene.vehicle_views == null:
		scene.camera.mode = ArenaCamera.Mode.CHASE
		scene.camera.local_target = scene.ctx.fighter(0)
	# All-Bot probes retain the previous presentation-only phone controls.
	if humans == 0:
		var layer := CanvasLayer.new()
		layer.layer = 8
		scene.add_child(layer)
		var touch := TouchSource.new()
		layer.add_child(touch)
		touch.setup(0, Registry.minigame(game))
		scene.camera.shared_touch_count = maxi(scene.camera.shared_touch_count, 1)
		touch.set_physics_process(false)
		touch.set_process_input(false)
	for fighter in scene.ctx.fighters:
		positions.append(fighter.global_position)
	start_us = Time.get_ticks_usec()
	last_us = start_us
	print("SOAK_START ", game, " / ", cfg.arena_id, " cap=", cap, " quality=", quality)
	report.merge({"game": game, "arena": cfg.arena_id, "engine": Engine.get_version_info().string,
		"human_slots": cfg.human_slots(), "bot_count": 4 - humans,
		"personal_view_count": scene.vehicle_views.viewports.size() if scene.vehicle_views != null else 0,
		"input_fixture": "scripted_touch_driving_and_firing" if firing else "scripted_touch_driving" if humans > 0 else "four_bots",
		"built_arena": scene.arena.def.id,
		"os": OS.get_name(), "renderer": RenderingServer.get_current_rendering_method(),
		"quality": quality, "cap": cap, "render_scale": get_viewport().scaling_3d_scale,
		"output_size": str(get_viewport().get_texture().get_size()), "requested_seconds": seconds})


func _physics_process(_delta: float) -> void:
	if scene == null or scene._paused:
		return
	if humans > 0 and scene.phase == MatchPhase.P.INSTRUCTIONS:
		scene.hud.ready_requested.emit()
		return
	if not MatchPhase.is_live(scene.phase):
		return
	for source in scene.touch_sources:
		drive_touch(source, live_seconds, firing)


static func drive_touch(source: TouchSource, elapsed: float, fire := false) -> void:
	# Repeatable workload, not a claim of human skill or a race-finishing agent.
	var steering := sin(elapsed * 0.5) * 0.6
	source._move = Vector2(steering, -1.0).normalized()
	source._steer = steering
	source._throttle = 1.0
	# Ordinary press/release pulses; ammo, cooldowns and collisions remain live.
	source._bits = InputFrame.Btn.ATTACK if fire and fposmod(elapsed + source.slot * 0.2, 0.9) < 0.12 else 0


func _process(_delta: float) -> void:
	if scene == null or done: return
	var now := Time.get_ticks_usec()
	var ms := (now - last_us) / 1000.0
	last_us = now
	var live: bool = scene.ctx != null and not scene._paused and MatchPhase.is_live(scene.phase)
	if live:
		if not trace_started:
			DevTools.operations.reset()
			pipeline_start = _pipeline_counts()
			previous_pipelines = pipeline_start.duplicate()
			trace_started = true
		var pipelines := _pipeline_counts()
		var live_size := str(get_viewport().get_texture().get_size())
		if not viewport_sizes.has(live_size):
			viewport_sizes.append(live_size)
		var window_size := str(DisplayServer.window_get_size())
		if not window_sizes.has(window_size):
			window_sizes.append(window_size)
		live_seconds += ms / 1000.0
		if live_seconds < 3.0:
			cold_samples.append(ms)
		else:
			samples.append(ms)
			if ms > 50.0:
				var pipeline_delta := {}
				for key in pipelines:
					pipeline_delta[key] = int(pipelines[key]) - int(previous_pipelines.get(key, 0))
				_record_slow_frame(ms, {"elapsed_seconds": live_seconds,
					"process_frame": Engine.get_process_frames(),
					"physics_frame": Engine.get_physics_frames(),
					"process_monitor_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
					"physics_monitor_ms": Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
					"pipeline_delta": pipeline_delta, "focused": DisplayServer.window_is_focused()})
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
		previous_pipelines = pipelines
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


func _record_slow_frame(ms: float, measurements: Dictionary) -> void:
	if not is_finite(ms) or ms <= 50.0:
		return
	var sample := measurements.duplicate(true)
	sample["frame_ms"] = ms
	slow_frames.append(sample)
	slow_frames.sort_custom(func(a, b): return a.frame_ms > b.frame_ms)
	if slow_frames.size() > 8:
		slow_frames.resize(8)


func _pipeline_counts() -> Dictionary:
	return {
		"canvas": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS),
		"mesh": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_MESH),
		"surface": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SURFACE),
		"draw": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_DRAW),
		"specialization": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_SPECIALIZATION),
	}


func _result_exit_code() -> int:
	var complete: bool = report.get("complete_duration", false) == true and not samples.is_empty()
	return 0 if complete and (not firing or projectile_peak > 0) else 1


func _finish() -> void:
	done = true
	set_process(false)
	report["steady"] = _stats(samples)
	report["first_3_seconds"] = _stats(cold_samples)
	report["live_seconds"] = live_seconds
	report["simulation_seconds"] = scene._round_elapsed
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
	report["slow_frame_samples"] = slow_frames
	report["operations"] = DevTools.operations.report()
	report["operation_trace_enabled"] = DevTools.operations.enabled
	var pipeline_delta := _pipeline_counts()
	for key in pipeline_delta:
		pipeline_delta[key] -= int(pipeline_start.get(key, 0))
	report["live_pipeline_compilations"] = pipeline_delta
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	report["startup_output_size"] = report["output_size"]
	report["output_size"] = str(image.get_size())
	report["live_texture_reported_sizes"] = viewport_sizes
	report["live_window_sizes"] = window_sizes
	image.save_png(output.trim_suffix(".json") + ".png")
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
	# Measurements are complete; drain playback before the engine removes its mixer.
	AudioManager.shutdown()
	await get_tree().process_frame
	await get_tree().process_frame
	OS.delay_msec(100)
	get_tree().quit(_result_exit_code())
