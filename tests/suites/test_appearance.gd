extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("appearance")
	var saved := UserSettings.snapshot()
	var old_size := host.get_window().size
	var language := Loc.locale
	for id in ["storm_heart", "symbol_echo", "quick_draw", "sky_court", "zone_hold", "gem_grab", "sabaq_sawarikh"]:
		var source := FileAccess.get_file_as_string("res://src/minigames/%s.gd" % id)
		t.ok(not source.contains("UIKit.ACCENT") and not source.contains("UIKit.PANEL_HI")
			and not source.contains("UIKit.DANGER"), "gameplay art is independent of UI appearance: " + id)
	for supported in [false, true]:
		for system_dark in [false, true]:
			for mode in ["system", "light", "dark"]:
				var expected: bool = mode == "dark" or (mode == "system" and (not supported or system_dark))
				t.equal(UITheme.resolve_dark(mode, supported, system_dark), expected, "device preference and explicit override resolve")
	UserSettings.set_value("appearance", "invalid")
	t.equal(UserSettings.get_value("appearance"), saved.appearance, "invalid appearance rejected")
	var fixture := UIKit.screen_root()
	host.add_child(fixture)
	var label := UIKit.label("Appearance")
	var button := UIKit.button("Button")
	var panel := UIKit.panel()
	var field := LineEdit.new()
	var option := UIKit.option(["One", "Two"], 0)
	var tinted := UIKit.panel(Color(0.1, 0.15, 0.1, 0.95))
	for node in [label, button, panel, field, option, tinted]:
		fixture.add_child(node)
	for dark in [false, true, false, true]:
		UserSettings.set_value("appearance", "dark" if dark else "light")
		await host.get_tree().process_frame
		t.equal(UIKit.dark_mode, dark, "setting updates live without replacing UI")
		t.equal(MeshFactory.WORLD_GOLD, Color("#ffb347"), "gold pickup cue unchanged")
		t.equal(MeshFactory.WORLD_TEAL, Color("#57e0c0"), "zone cue unchanged")
		t.equal(MeshFactory.WORLD_DANGER, Color("#ff5f6d"), "projectile cue unchanged")
		t.equal(MeshFactory.WORLD_PANEL, Color("#252c52"), "memory and reaction prop colour unchanged")
		t.equal(fixture.get_child(0).color, UIKit.BG, "existing background follows appearance")
		t.equal(label.get_theme_color("font_color"), UIKit.text_color(), "existing label follows appearance")
		t.equal(button.get_theme_color("font_color"), UIKit.text_color(), "existing button follows appearance")
		t.equal(field.get_theme_color("font_color"), UIKit.text_color(), "plain input inherits global appearance")
		t.equal(option.get_popup().get_theme_color("font_color"), UIKit.text_color(), "popup inherits appearance")
		t.equal(option.get_theme_constant("modulate_arrow"), 1, "dropdown arrow follows text contrast")
		for state in ["normal", "normal_mirrored", "hover", "hover_mirrored"]:
			var option_surface := option.get_theme_stylebox(state) as StyleBoxFlat
			t.ok(option_surface != null and _contrast(UIKit.text_color(), option_surface.bg_color) >= 4.5,
				"option contrast includes RTL state " + state)
		t.equal(SaveSystem.settings().appearance, "dark" if dark else "light", "appearance persisted with settings")
		var surface := panel.get_theme_stylebox("panel") as StyleBoxFlat
		t.ok(_contrast(UIKit.text_color(), surface.bg_color) >= 4.5, "panel text contrast at least 4.5:1")
		if not dark:
			t.ok(_contrast(UIKit.dim_color(), tinted.get_theme_stylebox("panel").bg_color) >= 4.5,
				"secondary text stays readable on custom tinted glass surfaces in light mode")
		for color in [UIKit.TEXT_DIM, UIKit.ACCENT, UIKit.ACCENT_2, UIKit.DANGER, UIKit.OK]:
			t.ok(_contrast(color, UIKit.BG) >= 4.5, "secondary semantic text stays readable")
	for contrast in [true, false]:
		UserSettings.set_value("high_contrast", contrast)
		for dark in [false, true]:
			UserSettings.set_value("appearance", "dark" if dark else "light")
			await host.get_tree().process_frame
			t.equal(label.get_theme_color("font_color"), UIKit.text_color(), "contrast survives both appearances")
	UserSettings.set_value("high_contrast", false)
	UserSettings.set_value("appearance", "system")
	await host.get_tree().process_frame
	t.equal(UIKit.dark_mode, UITheme.resolve_dark("system", DisplayServer.is_dark_mode_supported(),
		DisplayServer.is_dark_mode()), "system mode uses the actual display preference")
	fixture.queue_free()
	await host.get_tree().process_frame
	var visited := 0
	var routes: Array = SceneRouter.SCREENS.keys()
	if "--appearance-smoke" in OS.get_cmdline_user_args():
		routes = ["settings", "game_library", "characters", "touch_layout"]
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		for resolution in [Vector2i(540, 960), Vector2i(1280, 720)]:
			host.get_window().size = resolution
			for id in routes:
				if id == "match":
					continue
				UserSettings.set_value("appearance", "light")
				await host.get_tree().process_frame
				t.ok(await SceneRouter.go_to(id, {}, false, 0), "%s builds in %s/%s" % [id, locale, resolution])
				var screen_id: int = SceneRouter.current_node.get_instance_id()
				for mode in ["light", "dark"]:
					UserSettings.set_value("appearance", mode)
					await host.get_tree().process_frame
					var screen = SceneRouter.current_node
					t.ok(is_instance_valid(screen), "screen remains alive")
					t.equal(screen.get_instance_id(), screen_id, "theme switches without replacing %s" % id)
					if screen is Screen and screen.root != null:
						var bg := screen.root.get_child(0) as ColorRect
						if bg.color.a > 0:
							t.equal(bg.color, UIKit.BG, "routed screen uses current background")
					if id == "settings":
						var selector := screen.find_child("AppearanceOptions", true, false) as OptionButton
						t.equal(selector.selected, 1 if mode == "light" else 2, "appearance selector stays synchronized")
					if id == "characters":
						for frame in 3:
							await host.get_tree().process_frame
						var grid: GridContainer = screen.body.get_child(1).get_child(0)
						for i in grid.get_child_count():
							var card_button: Button = grid.get_child(i)
							t.ok(card_button.get_global_rect().grow(0.1).encloses(card_button.get_child(0).get_global_rect()),
								"selectable button contains its complete card")
							for j in range(i + 1, grid.get_child_count()):
								t.ok(not card_button.get_global_rect().intersects(grid.get_child(j).get_global_rect()),
									"character cards do not overlap after theme changes")
					visited += 1
					await _capture(t, host, "%s-%s-%s-%dx%d" % [locale, id, mode, resolution.x, resolution.y])
	t.equal(visited, (routes.size() - int("match" in routes)) * 8, "selected menu routes both themes/languages/orientations")
	print("APPEARANCE_SCREEN_MATRIX cases=%d" % visited)
	var cfg := MatchConfig.build("ring_rumble", ["nabta", "sakhra", "fanoos", "ramla"], 4, 1, 461)
	await SceneRouter.start_match(cfg)
	t.equal(SceneRouter.current_id, "match", "match opens for live appearance regression")
	var scene = SceneRouter.current_node
	var instance_id: int = scene.get_instance_id()
	var phase: int = scene.phase
	var identity: Color = cfg.players[0].color()
	var cue := OffscreenPlayerCue.new()
	host.add_child(cue)
	cue.configure(cfg.players[0])
	for mode in ["light", "dark"]:
		UserSettings.set_value("appearance", mode)
		await host.get_tree().process_frame
		t.equal(SceneRouter.current_node.get_instance_id(), instance_id, "appearance does not replace match")
		t.equal(scene.phase, phase, "appearance does not advance round")
		t.equal(cfg.players[0].color(), identity, "player identity colour unchanged")
		t.equal(cue._symbol.get_theme_color("font_color"), UIKit.text_color(), "offscreen cue follows appearance")
		t.equal(scene.hud._timer_label.get_theme_color("font_color"), UIKit.TEXT, "HUD timer updates live")
		var chip = scene.hud._chips[0]
		t.equal(chip.value.get_theme_color("font_color"), UIKit.text_color(), "score follows appearance")
		t.equal(chip.detail.get_theme_color("font_color"), UIKit.text_color(), "score detail follows appearance")
		var surface: StyleBoxFlat = chip.root.get_theme_stylebox("panel")
		t.ok(_contrast(UIKit.text_color(), surface.bg_color) >= 4.5, "player chip contrast in both appearances")
		await _capture(t, host, "match-" + mode)
	UserSettings.set_value("high_contrast", true)
	await host.get_tree().process_frame
	scene.hud._timer_label.add_theme_color_override("font_color", UIKit.TEXT)
	UserSettings.set_value("appearance", "light")
	await host.get_tree().process_frame
	t.equal(scene.hud._timer_label.get_theme_color("font_color"), UIKit.TEXT,
		"explicit HUD text token follows appearance even with high contrast enabled")
	cue.queue_free()
	await SceneRouter.go_to("main_menu", {}, false, 0)
	SceneRouter.clear_stack()
	host.get_window().size = old_size
	for key in ["appearance", "high_contrast"]:
		UserSettings.set_value(key, saved[key])
	Loc.set_locale(language)
	await host.get_tree().process_frame


func _capture(t: TestHarness, host: Node, filename: String) -> void:
	if not "--appearance-captures" in OS.get_cmdline_user_args():
		return
	if DisplayServer.get_name() == "headless":
		t.ok(false, "appearance screenshots require a renderer")
		return
	await host.get_tree().process_frame
	# A background/occluded macOS window may not emit frame_post_draw.
	# Force a draw for this test-only capture instead of waiting indefinitely.
	RenderingServer.force_draw(false)
	var output := SaveSystem.storage_root.path_join("screenshots")
	DirAccess.make_dir_recursive_absolute(output)
	var image := host.get_viewport().get_texture().get_image()
	t.ok(not image.is_empty(), "appearance image has pixels")
	var screen = SceneRouter.current_node
	if screen is Screen and screen.root != null and screen.root.get_child(0).color.a > 0:
		var pixel := image.get_pixel(1, 1)
		t.ok(Vector3(pixel.r, pixel.g, pixel.b).distance_to(Vector3(UIKit.BG.r, UIKit.BG.g, UIKit.BG.b)) < 0.04,
			"rendered background matches current appearance rather than a stale frame")
	t.equal(image.save_png(output.path_join(filename + ".png")), OK, "appearance screenshot saved")


func _luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return linear.r * 0.2126 + linear.g * 0.7152 + linear.b * 0.0722


func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
