extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("HUD stock and damage value fitting")
	var window := host.get_window()
	var old_size := window.size
	var old_locale := Loc.locale
	var old_scale = UserSettings.get_value("text_scale")
	var old_mobile := Platform.is_mobile
	var old_safe := Platform.safe_area
	var old_processing := Platform.is_processing()
	Platform.set_process(false)
	Platform.is_mobile = true
	var cases := 0
	var measurements: Array = []
	var capture := OS.get_cmdline_user_args().has("--hud-value-capture")
	var old_title := window.title
	if capture:
		window.title = "KRAS PASS HUD QA pid=%d" % OS.get_process_id()
	else:
		_test_fit_cache(t, host)
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		for roster in [[4, 1], [4, 2], [4, 3], [4, 4], [1, 1], [2, 2], [3, 3]]:
			var humans: int = roster[1]
			if capture and (roster[0] != 4 or humans not in [1, 4]):
				continue
			var characters := ["nabta", "sakhra", "fanoos", "ramla"].slice(0, roster[0])
			var cfg := MatchConfig.build("duel_pit", characters, humans, 1, 261122)
			for player in cfg.players:
				player.display_name_override = "A very long player identity 0123456789" if locale == "en" else "اسم لاعب طويل لاختبار مساحة القيمة والأرقام"
			var arena := Arena.new()
			arena.def = Registry.arena(cfg.arena_id)
			var context := MatchContext.new()
			context.config = cfg
			context.definition = cfg.definition()
			context.arena = arena
			context.scores.assign([0, 0, 0, 0].slice(0, cfg.player_count()))
			context.alive.assign([true, true, true, true].slice(0, cfg.player_count()))
			for slot in cfg.player_count():
				context.fighters.append(Fighter.new())
			var controller: MiniGameController = load("res://src/minigames/duel_pit.gd").new()
			controller.bind(context)
			controller.configure()
			controller._lives.assign([3, 3, 3, 3].slice(0, cfg.player_count()))
			var powerups := PowerUpSystem.new()
			powerups.ctx = context
			context.powerups = powerups
			var hud := MatchHUD.new()
			host.add_child(hud)
			hud.setup(context, controller)
			for scale in ([1.0] if capture else [1.0, 1.6]):
				UserSettings.set_value("text_scale", scale)
				for resolution in [Vector2i(540, 960), Vector2i(1280, 720)]:
					window.size = resolution
					for inset in ([0] if capture else [0, 24]):
						Platform.safe_area = Rect2i(Vector2i(inset, inset * 2), resolution - Vector2i(inset * 2, inset * 3))
						Platform.safe_area_changed.emit(Platform.safe_area)
						for stock in ([3] if capture else [0, 3, 13, 100, 999]):
							for damage in ([13] if capture else [0, 13, 100, 999]):
								var value_widths: Array[float] = []
								for effect_count in ([3] if capture else [0, 1, 3, Registry.powerups().size()]):
									controller._lives.fill(stock)
									powerups._effects.clear()
									for slot in cfg.player_count():
										context.fighter(slot).damage_percent = damage
										for effect in Registry.powerups().slice(0, effect_count):
											powerups._effects.append({"slot": slot, "def": effect, "remaining": 10.0})
									hud._refresh_chips()
									await _settle(host)
									t.test("%s players=%d humans=%d scale=%s window=%s inset=%d stock=%d damage=%d effects=%d" % [locale, cfg.player_count(), humans, scale, resolution, inset, stock, damage, effect_count])
									for chip in hud._chips:
										_check_chip(t, hud, chip, scale)
										if effect_count == 0 or capture:
											value_widths.append(chip.value.size.x)
										else:
											t.near(chip.value.size.x, value_widths[chip.slot], 1.0, "effects do not change allocated value width")
									if stock == 3 and damage == 13 and scale == 1.0 and inset == 0 and cfg.player_count() == 4 and humans in [1, 4]:
										for chip in hud._chips:
											var value: Label = chip.value
											measurements.append({"locale": locale, "humans": humans, "window": str(resolution), "slot": chip.slot,
												"effects": effect_count, "text": value.text, "width": value.size.x, "font_size": value.get_theme_font_size("font_size"),
												"text_width": value.get_theme_font("font").get_string_size(value.text, HORIZONTAL_ALIGNMENT_LEFT, -1, value.get_theme_font_size("font_size")).x,
												"lines": value.get_line_count(), "clip_text": value.clip_text})
										if capture and effect_count == 3:
											await _capture(t, host, "%s-h%d-%dx%d.png" % [locale, humans, resolution.x, resolution.y])
										if not capture and effect_count == 3:
											for chip in hud._chips:
												chip.value_fit_cache["test_reused"] = true
												hud._refresh_chips()
											for chip in hud._chips:
												t.ok(chip.value_fit_cache.has("test_reused"), "unchanged actual HUD refresh reuses cached metrics")
									cases += 1
			hud.free()
			powerups.free()
			controller.free()
			for fighter in context.fighters:
				fighter.free()
			arena.free()
	t.equal(cases, 8 if capture else 8960, "complete explicitly selected runtime matrix (capture is eight native presentations)")
	var report := FileAccess.open(SaveSystem.storage_root.path_join("hud-value-measurements.json"), FileAccess.WRITE)
	t.ok(report != null, "runtime width measurements saved")
	if report != null:
		report.store_string(JSON.stringify(measurements, "\t"))
		report.close()
	window.size = old_size
	Loc.set_locale(old_locale)
	UserSettings.set_value("text_scale", old_scale)
	Platform.is_mobile = old_mobile
	Platform.safe_area = old_safe
	Platform.safe_area_changed.emit(old_safe)
	Platform.set_process(old_processing)
	if capture:
		window.title = old_title
	t.equal(window.title, old_title, "window title restored (native QA title is capture-only)")


func _test_fit_cache(t: TestHarness, host: Node) -> void:
	t.test("font metrics cache invalidation")
	var old_scale = UserSettings.get_value("text_scale")
	UserSettings.set_value("text_scale", 1.0)
	var hud := MatchHUD.new()
	host.add_child(hud)
	var value := UIKit.label("♥3   13%", 40, UIKit.text_color(), true)
	value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.add_child(value)
	value.size = Vector2(100, 400)
	var chip := {"value": value, "value_font_size": 40}
	hud._chips.append(chip)
	hud._fit_chip_value(chip)
	_check_fit_result(t, chip)
	chip.value_fit_cache["test_reused"] = true
	for repeat in 100:
		hud._fit_chip_value(chip)
	t.ok(chip.value_fit_cache.has("test_reused"), "100 unchanged fits retain the cached metric result")
	value.text = "♥999   999%"
	_expect_cache_miss(t, hud, chip, "changed text")
	value.size.x = 70
	_expect_cache_miss(t, hud, chip, "changed actual width")
	chip.value_font_size = 36
	_expect_cache_miss(t, hud, chip, "changed preferred size")
	UserSettings.set_value("text_scale", 1.6)
	_expect_cache_miss(t, hud, chip, "changed accessibility minimum")
	var original_font := value.get_theme_font("font")
	var replacement := original_font.duplicate() as Font
	value.add_theme_font_override("font", replacement)
	var replacement_connections := replacement.changed.get_connections().size()
	_expect_cache_miss(t, hud, chip, "changed font resource")
	chip.value_fit_cache["test_reused"] = true
	original_font.emit_changed()
	t.ok(not chip.has("value_fit_cache"), "font resource edit conservatively invalidates HUD caches")
	hud._fit_chip_value(chip)
	_check_fit_result(t, chip)
	replacement.emit_changed()
	t.ok(not chip.has("value_fit_cache"), "in-place font change invalidates resource-identity cache")
	hud._fit_chip_value(chip)
	_check_fit_result(t, chip)
	chip.value_fit_cache["test_reused"] = true
	value.add_theme_font_size_override("font_size", 80)
	_expect_cache_miss(t, hud, chip, "externally changed fitted size")
	value.size.x = 240
	_expect_cache_miss(t, hud, chip, "wider actual allocation restores preferred size")
	t.equal(value.get_theme_font_size("font_size"), chip.value_font_size, "growth restores preferred font, not a stale smaller fit")
	var pending := Label.new()
	var pending_chip := {"value": pending, "value_font_size": 36}
	t.equal(pending.size.x, 0.0, "unallocated fixture has actual zero width")
	hud._fit_chip_value(pending_chip)
	t.ok(not pending_chip.has("value_fit_cache"), "unallocated width is not cached as a successful fit")
	pending.free()
	value.size.x = 70
	hud._fit_chip_value(chip)
	_check_fit_result(t, chip)
	hud.free()
	t.equal(replacement.changed.get_connections().size(), replacement_connections, "font callback removed when fitting HUD is freed")
	value.free()
	UserSettings.set_value("text_scale", old_scale)


func _expect_cache_miss(t: TestHarness, hud: MatchHUD, chip: Dictionary, reason: String) -> void:
	chip.value_fit_cache["test_reused"] = true
	hud._fit_chip_value(chip)
	t.ok(not chip.value_fit_cache.has("test_reused"), reason + " recomputes metrics")
	_check_fit_result(t, chip)


func _check_fit_result(t: TestHarness, chip: Dictionary) -> void:
	var value: Label = chip.value
	var font := value.get_theme_font("font")
	var minimum := mini(int(chip.value_font_size), int(ceilf(14.0 * UIKit.scale())))
	var expected := minimum
	# Independent ascending oracle: choose the largest size whose whole tokens fit.
	for candidate in range(minimum, int(chip.value_font_size) + 1):
		var fits := true
		for token in value.text.split(" ", false):
			if font.get_string_size(token, HORIZONTAL_ALIGNMENT_LEFT, -1, candidate).x > value.size.x:
				fits = false
		if fits:
			expected = candidate
	t.equal(value.get_theme_font_size("font_size"), expected, "cached fitting agrees with independent font-metric oracle")
	for token in value.text.split(" ", false):
		t.ok(font.get_string_size(token, HORIZONTAL_ALIGNMENT_LEFT, -1, expected).x <= value.size.x, "cache never falsely accepts an overflowing token")
	t.equal(chip.value_fit_cache.text, value.text, "cached text matches actual label")
	t.equal(chip.value_fit_cache.width, value.size.x, "cached allocation matches actual label")


func _check_chip(t: TestHarness, hud: MatchHUD, chip: Dictionary, scale: float) -> void:
	var value: Label = chip.value
	var bounds: Rect2 = chip.root.get_global_rect()
	t.equal(value.text, hud.controller.hud_value(chip.slot), "actual controller stock and damage retained verbatim")
	t.ok(not value.clip_text, "value never silently clips")
	t.equal(value.text_direction, Control.TEXT_DIRECTION_LTR, "stock/percent order stable in both locales")
	t.ok(value.size.x > 0.0, "value has a positive allocated width")
	var font := value.get_theme_font("font")
	var size := value.get_theme_font_size("font_size")
	var full_width := font.get_string_size(value.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	t.ok(full_width <= value.size.x + 1.0 or value.get_line_count() > 1, "overwide controller value actually wraps instead of disappearing")
	t.at_least(size, int(ceilf(14.0 * scale)), "fitting retains accessibility-scaled reading floor")
	for token in value.text.split(" ", false):
		t.ok(font.get_string_size(token, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= value.size.x + 1.0, "each complete stock/percent token fits actual runtime width: " + token)
	t.equal(value.get_visible_line_count(), value.get_line_count(), "all wrapped value lines visible")
	t.ok(value.get_combined_minimum_size().y <= value.size.y + 1.0, "wrapped value receives full height")
	t.ok(bounds.grow(1).encloses(value.get_global_rect()), "value stays inside its player chip")
	t.ok(hud._usable_rect().grow(1).encloses(value.get_global_rect()), "value stays in usable safe area")
	t.ok(not value.get_global_rect().intersects(chip.name.get_global_rect()), "long player identity cannot cover value")
	for effect in chip.effects.get_children():
		if effect.visible:
			t.ok(bounds.grow(1).encloses(effect.get_global_rect()), "every active effect remains inside chip")
			t.ok(not value.get_global_rect().intersects(effect.get_global_rect()), "active effects cannot steal or cover value space")


func _settle(host: Node) -> void:
	for frame in 8:
		await host.get_tree().process_frame


func _capture(t: TestHarness, host: Node, filename: String) -> void:
	t.ok(DisplayServer.get_name() != "headless", "capture requires native renderer")
	if DisplayServer.get_name() == "headless":
		return
	var window := host.get_window()
	var deadline := Time.get_ticks_msec() + 60000
	print("HUD_QA_WAIT_FOCUS %s title=%s timeout_ms=60000" % [filename, window.title])
	while (not window.has_focus() or Platform.is_backgrounded) and Time.get_ticks_msec() < deadline:
		await host.get_tree().create_timer(0.1).timeout
	t.ok(window.has_focus() and not Platform.is_backgrounded, "capture requires foreground test window within 60 seconds")
	if not window.has_focus() or Platform.is_backgrounded:
		return
	await RenderingServer.frame_post_draw
	t.ok(window.has_focus() and not Platform.is_backgrounded, "capture still foreground after frame draw")
	if not window.has_focus() or Platform.is_backgrounded:
		return
	var output := SaveSystem.storage_root.path_join("hud-value-screenshots")
	DirAccess.make_dir_recursive_absolute(output)
	t.equal(host.get_viewport().get_texture().get_image().save_png(output.path_join(filename)), OK, "save actual HUD viewport")
