extends "res://tests/duel_visibility_physics_host.gd"
## Explicitly STATIC visibility fixture, not live gameplay or device evidence.

var _failures: Array[String] = []
var _rows: Array = []


func _ready() -> void:
	set_physics_process(false)
	var expected := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--expect-method="):
			expected = arg.trim_prefix("--expect-method=")
	var adapter := RenderingServer.get_video_adapter_name()
	var method := RenderingServer.get_current_rendering_method()
	var driver := RenderingServer.get_current_rendering_driver_name()
	if SaveSystem.storage_root == SaveSystem.DIR or DisplayServer.get_name() == "headless" \
			or expected not in ["mobile", "forward_plus"] or method != expected or driver != "metal" \
			or adapter.is_empty() or "software" in adapter.to_lower() or "swiftshader" in adapter.to_lower() \
			or "llvmpipe" in adapter.to_lower():
		push_error("Static visibility capture requires isolated storage and the requested real Metal renderer")
		get_tree().quit(1)
		return
	var destination := SaveSystem.storage_root.path_join("screenshots")
	if DirAccess.dir_exists_absolute(destination):
		push_error("Capture destination already exists; do not overwrite evidence")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(destination)
	UserSettings.set_value("touch_controls", "on")
	UserSettings.set_value("replay_capture", false)
	UserSettings.set_value("announcer_enabled", false)
	for humans in [1, 4]:
		for locale in ["ar", "en"]:
			Loc.set_locale(locale)
			for resolution in [Vector2i(540, 960), Vector2i(1280, 720)]:
				await _pair(destination, humans, locale, resolution)
	var report := {"fixture": "static_visibility_not_live_gameplay", "adapter": adapter,
		"method": method, "driver": driver, "engine": Engine.get_version_info().string,
		"rows": _rows, "failures": _failures, "physicalDeviceQualified": false,
		"liveGameplayQualified": false}
	var report_path := SaveSystem.storage_root.path_join("visibility-capture.json")
	if FileAccess.file_exists(report_path):
		push_error("Capture report already exists")
		get_tree().quit(1)
		return
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	else:
		_failures.append("cannot write capture metadata")
	for failure in _failures:
		print("FAIL: " + failure)
	print("STATIC DUEL VISIBILITY: %d failures; not live gameplay" % _failures.size())
	AudioManager.shutdown()
	await get_tree().process_frame
	await get_tree().process_frame
	OS.delay_msec(100)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _pair(destination: String, humans: int, locale: String, resolution: Vector2i) -> void:
	get_window().size = resolution
	await get_tree().process_frame
	var cfg := MatchConfig.build("duel_pit", ["nabta", "sakhra", "fanoos", "ramla"], humans, 1, 220000000)
	cfg.allow_powerups = false
	for player in cfg.players:
		if player.is_human:
			player.device_type = 2
	var scene: Node = load("res://src/match/match_scene.gd").new()
	add_child(scene)
	scene.setup({"config": cfg})
	# Only this labelled fixture freezes time. No production pause/background
	# guards are changed or bypassed, and this is never called a gameplay run.
	scene.set_physics_process(false)
	scene._set_phase(MatchPhase.P.INSTRUCTIONS)
	scene._set_phase(MatchPhase.P.COUNTDOWN)
	scene._set_phase(MatchPhase.P.PLAYING)
	scene.camera.set_process(false)
	scene.camera.set_physics_process(false)
	scene.camera._intro_left = 0.0
	scene.arena.def = scene.arena.def.duplicate(true)
	for fighter in scene.ctx.fighters:
		fighter.set_physics_process(false)
		fighter.reset_physics_interpolation()
	# Let the real start announcement finish, rather than hiding an overlay or
	# comparing an obstructed before image to a later cleared HUD.
	if scene.hud._announcement_tween != null and scene.hud._announcement_tween.is_running():
		await scene.hud._announcement_tween.finished
	await get_tree().physics_frame
	await get_tree().physics_frame
	scene.arena.def.params["camera_occluder_alpha"] = 0.0
	scene.camera._process(0.0)
	await run_in_physics(func(): scene.camera._occlusion_fader.update(scene.camera, scene.arena, scene.camera.targets, 0.1))
	var camera_transform: Transform3D = scene.camera.global_transform
	var positions: Array = []
	for fighter in scene.ctx.fighters:
		positions.append(fighter.global_transform)
	var orientation := "portrait" if resolution.x < resolution.y else "landscape"
	var name := "h%d-%s-%s" % [humans, locale, orientation]
	await _capture(destination.path_join(name + "-before.png"))
	scene.arena.def.params.erase("camera_occluder_alpha")
	await run_in_physics(func(): scene.camera._occlusion_fader.update(scene.camera, scene.arena, scene.camera.targets, 0.1))
	var diagnostics: Dictionary = scene.camera._occlusion_fader.diagnostics()
	await _capture(destination.path_join(name + "-after.png"))
	if not scene.camera.global_transform.is_equal_approx(camera_transform):
		_failures.append(name + ": before/after camera moved")
	for i in scene.ctx.fighters.size():
		if not scene.ctx.fighter(i).global_transform.is_equal_approx(positions[i]):
			_failures.append(name + ": before/after fighter moved")
	_rows.append({"name": name, "mode": "static_spawn_fixture", "camera": str(camera_transform),
		"fighters": positions.map(func(value): return str(value)), "fade": diagnostics,
		"visualReviewRequired": true, "provesFourVisibleBodies": false})
	scene.teardown()
	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _capture(path: String) -> void:
	for frame in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if FileAccess.file_exists(path):
		_failures.append("existing screenshot: " + path)
		return
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(path) != OK:
		_failures.append("cannot capture " + path)
		return
	var colors := {}
	for y in range(0, image.get_height(), 13):
		for x in range(0, image.get_width(), 13):
			colors[image.get_pixel(x, y).to_html()] = true
	if colors.size() < 30:
		_failures.append("blank or invalid render: " + path)
