extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("Safe match layout")
	var window := host.get_window()
	var old_size := window.size
	var old_locale := Loc.locale
	var old_settings := UserSettings.snapshot()
	var old_mobile := Platform.is_mobile
	var old_pane: Rect2 = Platform._native_pane
	var old_safe := Platform.safe_area
	var old_last: Rect2i = Platform._last_safe
	var old_process := Platform.is_processing()
	var old_frames: Array[InputFrame] = InputRouter._frames
	var old_pending: Array = InputRouter._virtual_pending
	var old_sources: Array = InputRouter._sources
	var old_devices: Array = InputRouter._device_ids
	var old_profiles: Array = InputRouter._profiles
	var old_playback := InputRouter.playback_mode
	var old_input_physics := InputRouter.is_physics_processing()
	var connections := Platform.safe_area_changed.get_connections().size()
	Platform.set_process(false)
	InputRouter.set_physics_process(false)
	InputRouter.playback_mode = false
	InputRouter._frames = []
	InputRouter._virtual_pending = []
	InputRouter._sources = []
	InputRouter._device_ids = []
	InputRouter._profiles = []
	for slot in InputRouter.MAX_SLOTS:
		InputRouter._frames.append(InputFrame.new())
		InputRouter._virtual_pending.append(InputFrame.new())
		InputRouter._sources.append(InputRouter.Source.NONE)
		InputRouter._device_ids.append(-1)
		InputRouter._profiles.append(0)
	for pair in [["touch_controls", "on"], ["touch_scale", 1.0], ["touch_positions", {}], ["touch_left_handed", false], ["vibration", false]]:
		UserSettings.set_value(pair[0], pair[1])
	window.size = Vector2i(1920, 1080)
	Platform.is_mobile = true
	var smoke := OS.get_cmdline_user_args().has("--safe-match-smoke")
	var locales := ["ar"] if smoke else ["ar", "en"]
	var scales := [1.6] if smoke else [1.0, 1.6]
	var cases := 0
	for locale in locales:
		Loc.set_locale(locale)
		for text_scale in scales:
			UserSettings.set_value("text_scale", text_scale)
			for game in Registry.all_minigames():
				if smoke and game.id != "gem_grab":
					continue
				for humans in [1, 2, 4]:
					var cfg := MatchConfig.build(game.id, ["nabta", "sakhra", "fanoos", "ramla"], humans, 1, 804)
					for player in cfg.players:
						player.device_type = 2
					var arena := Arena.new()
					arena.def = Registry.arena(cfg.arena_id)
					var context := MatchContext.new()
					context.config = cfg
					context.definition = game
					context.arena = arena
					context.scores.assign([12, 8, 5, 3])
					context.alive.assign([true, true, true, true])
					var controller := MiniGameController.new()
					controller.bind(context)
					var hud := MatchHUD.new()
					host.add_child(hud)
					hud.setup(context, controller)
					hud.set_time(72, 10)
					hud.set_round(0, 3)
					hud._refresh_chips()
					var layer := CanvasLayer.new()
					host.add_child(layer)
					var sources: Array[TouchSource] = []
					for slot in humans:
						InputRouter.assign_touch(slot)
						var source := TouchSource.new()
						layer.add_child(source)
						source.setup(slot, game, slot, humans)
						source.set_physics_process(false)
						sources.append(source)
					hud.touch_sources = sources
					var hud_id := hud.get_instance_id()
					for pane in [Rect2(0, 0, 0.49, 1), Rect2(0.51, 0, 0.49, 1)]:
						t.test("%s humans=%d %s scale=%s pane=%s" % [game.id, humans, locale, text_scale, pane])
						Platform._native_pane = pane
						Platform._refresh_safe_area()
						hud.show_rules(true)
						await _settle(host)
						var safe := Rect2(Platform.safe_area)
						t.equal(host.get_viewport().get_visible_rect().size, Vector2(1920, 1080), "synthetic logical viewport is 1920x1080")
						var card := hud._rules_card.get_child(0) as Control
						_inside(t, safe, card.get_global_rect(), "rules card")
						_labels_fit(t, card)
						var scroll := card.get_child(0) as ScrollContainer
						var start := scroll.get_child(0).find_children("*", "Button", true, false)[0] as Button
						scroll.ensure_control_visible(start)
						await host.get_tree().process_frame
						_inside(t, scroll.get_global_rect(), start.get_global_rect(), "rules start action reachable by scrolling")
						scroll.scroll_vertical = 0
						hud.show_rules(false)
						hud.show_hints(true)
						hud.announce(game.display_name(), UIKit.ACCENT)
						await _settle(host)
						t.equal(hud.get_instance_id(), hud_id, "safe-area change retains HUD")
						t.equal(hud.ctx, context, "safe-area change retains match context")
						_inside(t, safe, hud._timer_label.get_global_rect(), "timer")
						t.equal(hud._timer_label.get_line_count(), 1, "timer remains one line")
						_inside(t, safe, hud._hint_label.get_global_rect(), "hint")
						_labels_fit(t, hud._hint_label)
						_inside(t, safe, hud._centre_label.get_global_rect(), "announcement")
						for chip in hud._chips:
							_inside(t, safe, chip.root.get_global_rect(), "player chip")
							var clock_rect := hud._timer_label.get_global_rect()
							t.ok(not clock_rect.intersects(chip.root.get_global_rect()), "timer does not overlap player chip")
						for source in sources:
							for rect in source.control_rects():
								_inside(t, safe, rect, "drawn touch target")
								if humans > 1:
									_inside(t, source.get_global_rect(), rect, "target stays in its player's region")
							_check_touch(t, host.get_viewport(), source, safe)
						cases += 1
					layer.free()
					hud.free()
					controller.free()
					arena.free()
					for slot in InputRouter.MAX_SLOTS:
						InputRouter.clear_slot(slot)
	var games := 1 if smoke else Registry.all_minigames().size()
	t.equal(cases, games * 3 * locales.size() * scales.size() * 2, "every selected game/count/locale/scale/pane case completed")
	print("SAFE_MATCH_MATRIX games=%d cases=%d smoke=%s" % [games, cases, smoke])
	window.size = old_size
	Platform.is_mobile = old_mobile
	Platform._native_pane = old_pane
	Platform.safe_area = old_safe
	Platform._last_safe = old_last
	Platform.safe_area_changed.emit(old_safe)
	Platform.set_process(old_process)
	for key in ["touch_controls", "touch_scale", "touch_positions", "touch_left_handed", "vibration", "text_scale"]:
		UserSettings.set_value(key, old_settings[key])
	Loc.set_locale(old_locale)
	InputRouter._frames = old_frames
	InputRouter._virtual_pending = old_pending
	InputRouter._sources = old_sources
	InputRouter._device_ids = old_devices
	InputRouter._profiles = old_profiles
	InputRouter.playback_mode = old_playback
	InputRouter.set_physics_process(old_input_physics)
	t.equal(Platform.safe_area_changed.get_connections().size(), connections, "HUD and touch connections do not leak")
	t.equal(window.size, old_size, "window fixture restored")
	t.equal(UserSettings.snapshot(), old_settings, "settings fixture restored")
	t.equal(Platform.safe_area, old_safe, "safe-area fixture restored")


func _check_touch(t: TestHarness, viewport: Viewport, source: TouchSource, safe: Rect2) -> void:
	var outside := Vector2(1800, 850) if safe.position.x == 0 else Vector2(100, 850)
	_touch(viewport, source.slot, outside, true)
	t.ok(source._owners.is_empty(), "reserved-side press cannot claim touch ownership")
	_touch(viewport, source.slot, outside, false)
	for index in source.buttons.size():
		var point := source.global_position + source._button_centre(index)
		_touch(viewport, source.slot, point, true)
		source._physics_process(0)
		InputRouter._physics_process(0)
		t.ok(InputRouter.frame(source.slot).held(ControlProfile.BUTTON_BITS[source.buttons[index]]), "drawn button routes action to its own player")
		_touch(viewport, source.slot, point, false)
	if ControlProfile.shows_move_stick(source.profile):
		var point := source.global_position + source._stick_centre()
		_touch(viewport, source.slot, point, true)
		var drag := InputEventScreenDrag.new()
		drag.index = source.slot
		drag.position = point - Vector2(0, 60 * source._scale)
		viewport.push_input(drag, true)
		source._physics_process(0)
		InputRouter._physics_process(0)
		t.ok(InputRouter.frame(source.slot).move.y < -0.1, "drawn movement stick routes drag to its own player")
		_touch(viewport, source.slot, point, false)
	if ControlProfile.shows_steering(source.profile):
		var point: Vector2 = source.global_position + source._steer_rects()[2].get_center()
		_touch(viewport, source.slot, point, true)
		source._physics_process(0)
		InputRouter._physics_process(0)
		t.ok(InputRouter.frame(source.slot).move.y < -0.5, "drawn throttle routes to its own player")
		_touch(viewport, source.slot, point, false)
	if ControlProfile.shows_aim_stick(source.profile):
		var point := source.global_position + source._aim_centre()
		_touch(viewport, source.slot, point, true)
		var drag := InputEventScreenDrag.new()
		drag.index = source.slot
		drag.position = point + Vector2(60 * source._scale, 0)
		viewport.push_input(drag, true)
		source._physics_process(0)
		InputRouter._physics_process(0)
		t.ok(InputRouter.frame(source.slot).aim.x > 0.1, "drawn aim stick routes drag to its own player")
		_touch(viewport, source.slot, point, false)
	if ControlProfile.full_screen_tap(source.profile) != 0:
		var point := safe.get_center() if source.touch_count == 1 else source.get_global_rect().get_center()
		_touch(viewport, source.slot, point, true)
		source._physics_process(0)
		InputRouter._physics_process(0)
		t.ok(InputRouter.frame(source.slot).held(ControlProfile.full_screen_tap(source.profile)), "reaction region routes to its own player")
		_touch(viewport, source.slot, point, false)
	source._physics_process(0)
	InputRouter._physics_process(0)
	t.ok(InputRouter.frame(source.slot).move.is_zero_approx() and InputRouter.frame(source.slot).aim.is_zero_approx() and InputRouter.frame(source.slot).bits == 0, "release clears routed input")


func _inside(t: TestHarness, outer: Rect2, inner: Rect2, name: String) -> void:
	t.ok(inner.has_area() and outer.grow(1).encloses(inner), "%s inside safe pane: outer=%s inner=%s" % [name, outer, inner])


func _labels_fit(t: TestHarness, node: Node) -> void:
	if node is Label and node.is_visible_in_tree():
		t.ok(node.get_combined_minimum_size().y <= node.size.y + 1, "text height fits: " + node.text)
		t.equal(node.get_visible_line_count(), node.get_line_count(), "all text lines visible: " + node.text)
	for child in node.get_children():
		_labels_fit(t, child)


func _touch(viewport: Viewport, index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	viewport.push_input(event, true)


func _settle(host: Node) -> void:
	for frame in 8:
		await host.get_tree().process_frame
