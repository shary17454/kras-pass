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
	await _environment_quality(t, host)
	for key in settings:
		UserSettings.set_value(key, settings[key])


func _environment_quality(t: TestHarness, host: Node) -> void:
	UserSettings.set_value("battery_saver", false)
	UserSettings.set_value("reduce_effects", false)
	UserSettings.set_value("graphics_quality", 3)
	var arena := Arena.new()
	host.add_child(arena)
	arena.build(Registry.arena("tank_foundry"))
	var env := arena._env.environment
	var sky := env.sky
	var rich := RenderingServer.get_current_rendering_method() == "forward_plus"
	for tier in [0, 1, 2, 3]:
		UserSettings.set_value("graphics_quality", tier)
		t.equal(env.ssao_enabled, rich and tier >= 1, "live environment contact shading follows tier %d" % tier)
		for effect in ["ssil_enabled", "ssr_enabled", "volumetric_fog_enabled"]:
			t.equal(env.get(effect), rich and tier >= 2, "live %s follows tier %d" % [effect, tier])
	UserSettings.set_value("reduce_effects", true)
	for effect in ["glow_enabled", "ssao_enabled", "ssil_enabled", "ssr_enabled", "volumetric_fog_enabled"]:
		t.ok(not env.get(effect), "reduce effects disables retained %s" % effect)
	UserSettings.set_value("reduce_effects", false)
	t.ok(env.glow_enabled, "leaving reduced effects restores authored glow")
	UserSettings.set_value("battery_saver", true)
	t.ok(not env.glow_enabled and not env.ssao_enabled and not env.ssr_enabled,
		"saver disables retained environment effects immediately")
	UserSettings.set_value("battery_saver", false)
	var world: Node3D = load("res://src/arenas/natural_valley.gd").new()
	world.arena = arena
	world._lighting()
	var fog_color := env.fog_light_color
	var exposure := env.tonemap_exposure
	UserSettings.set_value("reduce_effects", true)
	UserSettings.set_value("reduce_effects", false)
	UserSettings.set_value("graphics_quality", 0)
	UserSettings.set_value("graphics_quality", 3)
	t.ok(not env.glow_enabled and not env.volumetric_fog_enabled,
		"quality restoration respects woodland authored disabled effects")
	t.ok(arena._env.environment == env and env.sky == sky,
		"live environment quality retains the original resources")
	t.equal(env.fog_light_color, fog_color, "live quality preserves authored fog color")
	t.near(env.tonemap_exposure, exposure, 0.00001, "live quality preserves authored exposure")
	world.free()
	arena.queue_free()
	await host.get_tree().process_frame
	UserSettings.set_value("battery_saver", true)
	var low_arena := Arena.new()
	host.add_child(low_arena)
	low_arena.build(Registry.arena("tank_foundry"))
	var low_env := low_arena._env.environment
	t.ok(not low_env.glow_enabled and not low_env.ssao_enabled,
		"arenas constructed in saver start without costly environment effects")
	UserSettings.set_value("battery_saver", false)
	t.ok(low_env.glow_enabled, "an arena constructed in saver restores configured glow")
	t.equal(low_env.ssao_enabled, rich, "an arena constructed in saver restores contact shading")
	t.near(low_env.glow_intensity, 0.5, 0.00001, "restored effects retain their authored parameters")
	low_arena.set_environment_effects(true, false)
	UserSettings.set_value("battery_saver", true)
	UserSettings.set_value("battery_saver", false)
	t.ok(low_env.glow_enabled and not low_env.volumetric_fog_enabled,
		"fantasy-style policy restores glow without reintroducing volumetric fog")
	low_arena.queue_free()
	await host.get_tree().process_frame


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
			var env := arena._env.environment
			t.ok(not env.glow_enabled and not env.ssao_enabled and not env.ssr_enabled,
				"actual settings control disables paused match environment effects")
			saver.button_pressed = false
			t.ok(not bool(UserSettings.get_value("battery_saver")) and arena._light.shadow_enabled,
				"actual settings control restores paused match shadows")
			t.ok(env.glow_enabled, "actual settings control restores paused match environment effects")
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
