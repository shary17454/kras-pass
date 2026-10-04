extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("live arena shadow quality")
	var settings := UserSettings.snapshot()
	UserSettings.set_value("battery_saver", false)
	UserSettings.set_value("graphics_quality", 3)
	var initial_connections := UserSettings.changed.get_connections().size()
	var arena := Arena.new()
	host.add_child(arena)
	arena.build(Registry.arena("tank_foundry"))
	var light := arena._light
	var environment := arena._env.environment
	var spawns := arena.spawn_points.duplicate()
	var static_root := arena._static_root
	light.rotation = Vector3(-0.55, -0.83, 0.1)
	light.light_color = Color("c5dce5")
	light.light_energy = 0.95
	light.shadow_normal_bias = 0.45
	var authored_rotation := light.rotation
	t.ok(light.shadow_enabled, "ultra starts with shadows")
	UserSettings.set_value("battery_saver", true)
	t.ok(not light.shadow_enabled, "enabling saver immediately disables an existing arena's shadows")
	t.equal(UserSettings.get_value("fps_limit"), 30, "saver still applies the existing 30 FPS preference")
	UserSettings.set_value("battery_saver", false)
	t.ok(light.shadow_enabled, "leaving saver restores the preferred shadow tier")
	for quality in [0, 1, 2, 3, 0, 3]:
		UserSettings.set_value("graphics_quality", quality)
		t.equal(light.shadow_enabled, quality >= 1, "live shadow enable follows tier %d" % quality)
		t.equal(light.directional_shadow_mode,
			DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if quality >= 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS,
			"live cascade count follows tier %d" % quality)
		t.equal(light.directional_shadow_blend_splits, quality >= 2, "live cascade blending follows tier %d" % quality)
		t.near(light.light_angular_distance, 1.1 if quality >= 2 else 0.0, 0.00001,
			"live sun softness follows tier %d" % quality)
		t.ok(arena._light == light and arena._env.environment == environment and arena._static_root == static_root,
			"tier changes never rebuild lights, environment or physical arena")
		t.equal(arena.spawn_points, spawns, "tier changes preserve authored spawn points")
		t.equal(light.rotation, authored_rotation, "tier changes preserve authored sun direction")
		t.equal(light.light_color, Color("c5dce5"), "tier changes preserve authored sunlight color")
		t.near(light.light_energy, 0.95, 0.00001, "tier changes preserve authored sunlight intensity")
		t.near(light.shadow_normal_bias, 0.45, 0.00001, "tier changes preserve authored contact bias")
	t.equal(UserSettings.changed.get_connections().size(), initial_connections + 1,
		"tier changes retain exactly one live arena listener")
	var was_paused := host.get_tree().paused
	host.get_tree().paused = true
	UserSettings.set_value("battery_saver", true)
	t.ok(not light.shadow_enabled, "paused settings can disable shadows without another gameplay frame")
	UserSettings.set_value("battery_saver", false)
	t.ok(light.shadow_enabled, "paused settings restore the preferred shadows immediately")
	host.get_tree().paused = was_paused
	UserSettings.set_value("graphics_quality", 0)
	UserSettings.reset_to_defaults()
	t.ok(light.shadow_enabled, "reset-to-defaults updates the existing arena")
	t.equal(light.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS,
		"reset-to-defaults restores the default high cascade tier")
	arena.queue_free()
	await host.get_tree().process_frame
	t.equal(UserSettings.changed.get_connections().size(), initial_connections,
		"freed arenas leave no settings callback behind")
	await _actual_pause_settings(t, host)
	for key in settings:
		UserSettings.set_value(key, settings[key])


func _actual_pause_settings(t: TestHarness, host: Node) -> void:
	var cfg := MatchConfig.build("ring_rumble", ["nabta", "sakhra", "barq", "turs"], 1, 2, 337)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_result): pass})
	scene.set_physics_process(false)
	scene._set_phase(MatchPhase.P.INSTRUCTIONS)
	scene._set_phase(MatchPhase.P.COUNTDOWN)
	scene._set_phase(MatchPhase.P.PLAYING)
	var context: MatchContext = scene.ctx
	var arena: Arena = scene.arena
	var connections := UserSettings.changed.get_connections().size()
	scene._toggle_pause()
	t.ok(scene._paused, "actual pause menu holds gameplay")
	var settings_button: Button
	for button in scene._pause_menu.find_children("*", "Button", true, false):
		if button.text == Loc.t("pause.settings"):
			settings_button = button
			break
	t.not_null(settings_button, "actual pause menu exposes settings")
	if settings_button != null:
		settings_button.pressed.emit()
		var sheet: CanvasLayer = scene.get_children().back()
		var screen: Control = sheet.get_child(0)
		var saver: CheckButton
		for button in screen.find_children("*", "CheckButton", true, false):
			for sibling in button.get_parent().get_children():
				if sibling is Label and sibling.text == Loc.t("party.battery_saver"):
					saver = button
					break
			if saver != null:
				break
		t.not_null(saver, "real settings sheet exposes the battery toggle")
		if saver != null:
			saver.button_pressed = true
			t.ok(bool(UserSettings.get_value("battery_saver")) and not arena._light.shadow_enabled,
				"actual settings control disables paused match shadows")
			saver.button_pressed = false
			t.ok(not bool(UserSettings.get_value("battery_saver")) and arena._light.shadow_enabled,
				"actual settings control restores paused match shadows")
			t.ok(scene._paused and scene.ctx == context and scene.arena == arena,
				"settings preserve the paused match instead of opening a replacement")
			t.equal(UserSettings.changed.get_connections().size(), connections,
				"opening in-match settings does not duplicate the arena listener")
			screen.args.close_callback.call()
			await host.get_tree().process_frame
			t.ok(not is_instance_valid(sheet), "closing real settings removes its sheet")
	scene._toggle_pause()
	t.ok(not scene._paused and scene.ctx == context, "actual resume keeps the same gameplay context")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
