extends RefCounted

var completed := false

class MetricsBridge extends RefCounted:
	signal viewport_metrics_received(metrics: Dictionary)
	var requests := 0

	func request_viewport_metrics() -> void:
		requests += 1


func run(t: TestHarness, host: Node) -> void:
	completed = false
	t.suite("Duo standings resize")
	var window := host.get_tree().root
	var old_size := window.size
	var old_scale = UserSettings.get_value("text_scale")
	var old_appearance = UserSettings.get_value("appearance")
	var old_locale := Loc.locale
	_check_safe_area(t, host)
	_check_pane_geometry(t)
	_check_metrics_delivery(t, host)
	var clock := UIKit.centered("0:00")
	t.equal(clock.autowrap_mode, TextServer.AUTOWRAP_OFF, "shared centered clock must not wrap")
	clock.free()
	if OS.get_cmdline_user_args().has("--duo-geometry-only"):
		completed = true
		return
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		for text_scale in [1.0, 1.6]:
			UserSettings.set_value("text_scale", text_scale)
			for complete in [false, true]:
				var session := TournamentSession.new()
				var cfg := MatchConfig.build("gem_grab", ["nabta", "sakhra", "fanous", "ramla"], 1, 1, 42)
				cfg.players[0].display_name_override = "لاعب البطولة صاحب الاسم الطويل" if locale == "ar" else "Tournament player with a long name"
				session.setup(cfg.players, ["gem_grab", "ring_rumble", "quick_draw"] as Array[String], 42)
				session.points.assign([12, 8, 5, 3])
				session.index = 3 if complete else 1
				session.last_awards.assign([5, 3, 2, 1])
				var screen: Screen = load("res://src/ui/screens/standings_screen.gd").new()
				host.add_child(screen)
				screen.setup({"session": session, "last": MatchResult.new()})
				var identity := screen.get_instance_id()
				var body_identity := screen.body.get_instance_id()
				var rows := session.rows().duplicate(true)
				var action := screen.first_focus
				for mode in ["dark", "light"]:
					UserSettings.set_value("appearance", mode)
					# Logical test sizes, not hardware/model detection constants.
					for resolution in [Vector2i(360, 780), Vector2i(699, 1017), Vector2i(1017, 699), Vector2i(1427, 1004), Vector2i(1004, 1427), Vector2i(360, 780)]:
						window.size = resolution
						for frame in 12:
							await host.get_tree().process_frame
						t.test("%s scale=%s complete=%s %s %s" % [locale, text_scale, complete, mode, resolution])
						var view := host.get_viewport().get_visible_rect()
						t.equal(UIKit.dark_mode, mode == "dark", "appearance applied")
						var background := screen.root.get_child(0) as ColorRect
						t.equal(background.color, UIKit.BG, "existing root background follows appearance")
						var title := screen.find_child("ScreenTitle", true, false) as Label
						t.equal(title.get_theme_font_size("font_size"), int(UIKit.SIZE_HEADING * text_scale), "header honors text scale")
						t.equal(title.get_theme_color("font_color"), UIKit.ACCENT, "header follows appearance")
						t.ok(view.encloses(screen.header.get_global_rect()), "header stays inside viewport")
						t.equal(screen.get_instance_id(), identity, "resize keeps screen")
						t.equal(screen.body.get_instance_id(), body_identity, "resize does not rebuild content")
						t.equal(screen.session, session, "session retained")
						t.equal(session.rows(), rows, "rankings and scores retained")
						t.equal(screen.first_focus, action, "primary action retained")
						t.equal(screen.root.is_layout_rtl(), locale == "ar", "root direction follows locale")
						t.ok(view.encloses(action.get_global_rect()), "primary action remains visible")
						_scan(t, screen, view)
						var scroll: ScrollContainer = screen.body.get_parent()
						t.greater(scroll.size.y, 80.0, "results scroll has usable height")
						scroll.scroll_vertical = 100000
						await host.get_tree().process_frame
						var grid := screen.find_child("StandingsRows", true, false) as Control
						t.equal(grid.get_child_count(), 4, "all results remain present")
						var last_row: Control = grid.get_child(3)
						scroll.ensure_control_visible(last_row)
						for frame in 3:
							await host.get_tree().process_frame
						t.ok(scroll.get_global_rect().intersects(last_row.get_global_rect()), "last result reachable by scrolling")
						scroll.scroll_vertical = 0
				screen.queue_free()
				await host.get_tree().process_frame
	window.size = old_size
	Loc.set_locale(old_locale)
	UserSettings.set_value("text_scale", old_scale)
	UserSettings.set_value("appearance", old_appearance)
	await _check_reserved_standings(t, host)
	completed = true


func _check_pane_geometry(t: TestHarness) -> void:
	t.test("normalized safe panes exclude active reserved geometry")
	var metrics := {"valid": true, "safe_rect": Rect2(0, 0, 1, 1), "occlusions": [], "divisions": []}
	t.equal(Platform.pane_for_metrics(metrics), Rect2(0, 0, 1, 1), "iOS 18 empty geometry preserves full safe area")
	metrics.divisions = [Rect2(0.5, 0, 0, 1)]
	var gap := Vector2(8.0 / 1920.0, 8.0 / 1080.0)
	var line_pane := Platform.pane_for_metrics(metrics, Rect2(), gap)
	t.near(line_pane.size.x * 1920.0, 956.0, 0.0001, "zero-width division reserves eight logical units")
	t.ok(not line_pane.intersects(Rect2(0.5 - gap.x / 2, 0, gap.x, 1)), "vertical line clearance excludes entire reserved gap")
	t.ok(Platform.pane_for_metrics(metrics).size.x < 0.5, "default epsilon also reserves zero-width division")
	metrics.divisions = [Rect2(0, 0.5, 1, 0)]
	line_pane = Platform.pane_for_metrics(metrics, Rect2(), gap)
	t.near(line_pane.size.y * 1080.0, 536.0, 0.0001, "zero-height division reserves eight logical units")
	metrics.divisions = [Rect2(0.5, 0, 0, 1), Rect2(0, 0.5, 1, 0)]
	line_pane = Platform.pane_for_metrics(metrics, Rect2(), gap)
	t.near(line_pane.get_area(), (956.0 / 1920.0) * (536.0 / 1080.0), 0.000001, "crossing zero-area divisions retain largest quadrant")
	metrics.divisions = [Rect2(0.5, 0.5, 0, 0)]
	t.equal(Platform.pane_for_metrics(metrics), Rect2(0, 0, 1, 1), "point without line extent does not reject complete metrics")
	metrics.divisions = [Rect2(0.49, 0, 0.02, 1)]
	var left := Rect2(0, 0, 0.49, 1)
	var right := Rect2(0.51, 0, 0.49, 1)
	t.equal(Platform.pane_for_metrics(metrics), left, "vertical division chooses deterministic largest pane")
	t.equal(Platform.pane_for_metrics(metrics, right), right, "equal areas retain previous side")
	metrics.occlusions = [Rect2(0, 0, 0.2, 1)]
	t.equal(Platform.pane_for_metrics(metrics, left), right, "larger clear pane wins over previous side")
	metrics.divisions = [Rect2(0, 0.4, 1, 0.1)]
	metrics.occlusions = []
	t.equal(Platform.pane_for_metrics(metrics), Rect2(0, 0.5, 1, 0.5), "horizontal active division chooses lower pane")
	metrics.divisions = []
	metrics.occlusions = [Rect2(0.4, 0.4, 0.2, 0.2)]
	var pane := Platform.pane_for_metrics(metrics)
	t.near(pane.get_area(), 0.4, 0.000001, "floating occlusion retains maximal rectangular strip")
	t.ok(not pane.intersects(metrics.occlusions[0]), "pane never intersects occlusion")
	metrics.safe_rect = Rect2(0.05, 0.1, 0.9, 0.8)
	metrics.occlusions = [Rect2(-1, -1, 0.5, 0.5)]
	t.equal(Platform.pane_for_metrics(metrics), metrics.safe_rect, "offscreen geometry leaves asymmetric safe area intact")
	metrics.occlusions = [Rect2(0, 0, 1, 1)]
	t.equal(Platform.pane_for_metrics(metrics), Rect2(), "fully occluded view cannot manufacture a safe pane")
	for bad in [Rect2(0, 0, -1, 1), Rect2(), Rect2(INF, 0, 1, 1)]:
		metrics.safe_rect = bad
		t.equal(Platform.pane_for_metrics(metrics), Rect2(), "invalid safe rectangle rejected")
	metrics.safe_rect = Rect2(0, 0, 1, 1)
	metrics.occlusions = [Rect2(0, 0, -1, 1)]
	t.equal(Platform.pane_for_metrics(metrics), Rect2(), "malformed obstacle rejects snapshot, not just obstacle")
	metrics.occlusions = []
	metrics.valid = false
	t.equal(Platform.pane_for_metrics(metrics), Rect2(), "missing native view does not supply geometry")
	_check_pane_oracle(t)
	t.equal(Platform.normalized_pane_pixels(Rect2(0.101, 0.102, 0.798, 0.796), Vector2i(100, 100)),
		Rect2i(11, 11, 78, 78), "pixel rounding stays strictly inside normalized safe bounds")


func _check_pane_oracle(t: TestHarness) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261121
	for sample in 20:
		var cuts: Array[Rect2] = []
		for index in 4:
			var x := rng.randi_range(0, 7)
			var y := rng.randi_range(0, 7)
			cuts.append(Rect2(x / 8.0, y / 8.0, rng.randi_range(1, 8 - x) / 8.0, rng.randi_range(1, 8 - y) / 8.0))
		var metrics := {"valid": true, "safe_rect": Rect2(0, 0, 1, 1), "occlusions": cuts.slice(0, 2), "divisions": cuts.slice(2)}
		var pane := Platform.pane_for_metrics(metrics)
		var largest := 0.0
		# Exhaustive grid rectangles are an independent oracle for grid-aligned cuts.
		for left in 8:
			for right in range(left + 1, 9):
				for top in 8:
					for bottom in range(top + 1, 9):
						var candidate := Rect2(left / 8.0, top / 8.0, (right - left) / 8.0, (bottom - top) / 8.0)
						var clear := true
						for cut in cuts:
							if candidate.intersects(cut):
								clear = false
								break
						if clear:
							largest = maxf(largest, candidate.get_area())
		t.near(pane.get_area(), largest, 0.0000001, "largest pane agrees with exhaustive oracle sample %d" % sample)
		for cut in cuts:
			t.ok(not pane.has_area() or not pane.intersects(cut), "selected pane excludes every overlapping cut")


func _check_metrics_delivery(t: TestHarness, host: Node) -> void:
	t.test("async metrics serialize requests and reject resized snapshots")
	var platform = load("res://src/core/platform_service.gd").new()
	host.add_child(platform)
	platform.is_mobile = true
	var bridge := MetricsBridge.new()
	platform._metrics_bridge = bridge
	bridge.viewport_metrics_received.connect(platform._on_viewport_metrics)
	platform._request_viewport_metrics()
	platform._request_viewport_metrics()
	t.equal(bridge.requests, 1, "only one request outstanding without native IDs")
	var metrics := {"valid": true, "safe_rect": Rect2(0, 0, 1, 1), "occlusions": [], "divisions": [Rect2(0.49, 0, 0.02, 1)]}
	var original_size := host.get_window().size
	host.get_window().size = original_size + Vector2i(20, 10)
	platform._refresh_safe_area()
	host.get_window().size = original_size
	platform._refresh_safe_area()
	bridge.viewport_metrics_received.emit(metrics)
	t.equal(platform._native_pane, Rect2(), "resize invalidates pending snapshot even if size returns to original")
	platform._request_viewport_metrics()
	bridge.viewport_metrics_received.emit(metrics)
	var retained: Rect2 = platform._native_pane
	t.ok(retained.has_area(), "next fresh snapshot accepted")
	t.equal(platform.safe_area, Platform.normalized_pane_pixels(retained, host.get_window().size), "native pane and insets use current window coordinates")
	for line in [Rect2(0.5, 0, 0, 1), Rect2(0, 0.5, 1, 0)]:
		metrics.divisions = [line]
		platform._request_viewport_metrics()
		bridge.viewport_metrics_received.emit(metrics)
		var ui := host.get_viewport().get_visible_rect().size
		retained = Platform.pane_for_metrics(metrics, retained, Vector2(8, 8) / ui)
		t.equal(platform._native_pane, retained, "native zero-area division uses logical eight-unit gap")
		t.equal(platform.safe_area, Platform.normalized_pane_pixels(retained, host.get_window().size), "zero-area division updates physical safe pane")
	platform._request_viewport_metrics()
	bridge.viewport_metrics_received.emit({"valid": false})
	t.equal(platform._native_pane, retained, "temporarily missing game view retains last safe pane")
	platform._request_viewport_metrics()
	platform._process(1.01)
	t.equal(platform._metrics_bridge, null, "lost callback disables bridge instead of freezing future updates")
	t.equal(platform._native_pane, Rect2(), "unavailable bridge restores DisplayServer fallback")
	bridge.viewport_metrics_received.emit(metrics)
	t.equal(platform._native_pane, Rect2(), "late timed-out callback cannot overwrite fallback")
	platform.free()


func _check_reserved_standings(t: TestHarness, host: Node) -> void:
	var window := host.get_window()
	var old_size := window.size
	var old_mobile := Platform.is_mobile
	var old_pane: Rect2 = Platform._native_pane
	var old_locale := Loc.locale
	var old_scale = UserSettings.get_value("text_scale")
	var old_mode = UserSettings.get_value("appearance")
	window.size = Vector2i(1427, 1004)
	Platform.is_mobile = true
	Platform._native_pane = Platform.pane_for_metrics({"valid": true, "safe_rect": Rect2(0, 0, 1, 1), "occlusions": [], "divisions": [Rect2(0.49, 0, 0.02, 1)]})
	Platform._refresh_safe_area()
	var gap := Vector2(8, 8) / host.get_viewport().get_visible_rect().size
	var line_metrics := {"valid": true, "safe_rect": Rect2(0, 0, 1, 1), "occlusions": [], "divisions": [Rect2(0.5, 0, 0, 1)]}
	var line_left := Platform.pane_for_metrics(line_metrics, Rect2(), gap)
	var line_right := Platform.pane_for_metrics(line_metrics, Rect2(0.51, 0, 0.49, 1), gap)
	for locale in ["ar", "en"]:
		Loc.set_locale(locale)
		for text_scale in [1.0, 1.6]:
			UserSettings.set_value("text_scale", text_scale)
			for mode in ["dark", "light"]:
				UserSettings.set_value("appearance", mode)
				var session := TournamentSession.new()
				var cfg := MatchConfig.build("gem_grab", ["nabta", "sakhra", "fanous", "ramla"], 1, 1, 42)
				session.setup(cfg.players, ["gem_grab"] as Array[String], 42)
				session.index = 1
				var screen: Screen = load("res://src/ui/screens/standings_screen.gd").new()
				host.add_child(screen)
				screen.setup({"session": session})
				var identity := screen.get_instance_id()
				var body_identity := screen.body.get_instance_id()
				var rows := session.rows().duplicate(true)
				var action := screen.first_focus
				for pane in [Rect2(0, 0, 0.49, 1), Rect2(0.51, 0, 0.49, 1), line_left, line_right, Rect2(0, 0, 1, 1), Rect2(0, 0, 0.49, 1)]:
					Platform._native_pane = pane
					Platform._refresh_safe_area()
					for frame in 12:
						await host.get_tree().process_frame
					t.test("reserved division standings %s %s %s %s" % [locale, text_scale, mode, pane])
					var view := host.get_viewport().get_visible_rect()
					var insets := Platform.safe_insets()
					var safe := Rect2(Vector2(insets.x, insets.y), view.size - Vector2(insets.x + insets.z, insets.y + insets.w))
					t.ok(safe.grow(1).encloses(screen.header.get_global_rect()), "header respects reserved pane")
					t.ok(safe.grow(1).encloses(screen.first_focus.get_global_rect()), "action respects reserved pane")
					_scan(t, screen.body, safe)
					t.equal(screen.get_instance_id(), identity, "pane update retains screen")
					t.equal(screen.body.get_instance_id(), body_identity, "pane update retains body")
					t.equal(screen.session, session, "pane update retains session")
					t.equal(session.rows(), rows, "pane update retains rankings and scores")
					t.equal(screen.first_focus, action, "pane update retains primary action")
					var background := screen.root.get_child(0) as ColorRect
					t.ok(background.get_global_rect().encloses(view), "background remains full viewport, never cropped to pane")
				screen.free()
	window.size = old_size
	Platform.is_mobile = old_mobile
	Platform._native_pane = old_pane
	Platform._refresh_safe_area()
	Loc.set_locale(old_locale)
	UserSettings.set_value("text_scale", old_scale)
	UserSettings.set_value("appearance", old_mode)


func _check_safe_area(t: TestHarness, host: Node) -> void:
	t.test("asymmetric safe area updates without resize")
	t.equal(Platform.safe_insets_for_rect(Rect2i(40, 30, 900, 710), Vector2(1000, 800), Vector2(2000, 1600)),
		Vector4(80, 60, 120, 120), "four independent edges mapped to UI coordinates")
	t.equal(Platform.safe_insets_for_rect(Rect2i(-20, -10, 1100, 900), Vector2(1000, 800), Vector2(2000, 1600)),
		Vector4.ZERO, "out of bounds report cannot create negative margins")
	t.equal(Platform.safe_insets_for_rect(Rect2i(), Vector2.ZERO, Vector2(720, 1280)),
		Vector4.ZERO, "zero-sized window remains safe")
	for invalid in [Rect2i(20, 30, -16, -6), Rect2i(20, 30, -16, 10), Rect2i(20, 30, 10, -6), Rect2i(20, 30, 0, 10), Rect2i(20, 30, 10, 0)]:
		t.equal(Platform.safe_insets_for_rect(invalid, Vector2(64, 64), Vector2(1920, 1080)),
			Vector4.ZERO, "invalid report rejected before intersection: " + str(invalid))
	for invalid_ui in [Vector2.ZERO, Vector2(-1, 100), Vector2(INF, 100)]:
		t.equal(Platform.safe_insets_for_rect(Rect2i(10, 10, 20, 20), Vector2(64, 64), invalid_ui),
			Vector4.ZERO, "invalid UI size rejected")
	var original_mobile := Platform.is_mobile
	var original_safe := Platform.safe_area
	var window_size := host.get_window().size
	var before := Platform.safe_area_changed.get_connections().size()
	var fixture := UIKit.margin(Control.new(), 12)
	host.add_child(fixture)
	Platform.is_mobile = true
	var physical := host.get_window().size
	var inset := Vector2i(maxi(1, physical.x / 10), maxi(1, physical.y / 8))
	Platform.safe_area = Rect2i(inset, physical - inset * 3)
	t.ok(Platform.safe_area.has_area(), "safe-area fixture has positive dimensions even at 64x64")
	Platform.safe_area_changed.emit(Platform.safe_area)
	var expected := Platform.ui_margin(12)
	for side in ["left", "top", "right", "bottom"]:
		t.equal(fixture.get_theme_constant("margin_" + side), expected[side], "margin updates on safe-area signal: " + side)
	t.equal(host.get_window().size, window_size, "safe-area update does not require window resize")
	Platform.is_mobile = original_mobile
	Platform.safe_area = original_safe
	Platform.safe_area_changed.emit(original_safe)
	host.remove_child(fixture)
	fixture.free()
	t.equal(Platform.safe_area_changed.get_connections().size(), before, "margin disconnects on exit")


func _scan(t: TestHarness, node: Node, view: Rect2) -> void:
	if node is Control and node.is_visible_in_tree():
		var rect: Rect2 = node.get_global_rect()
		t.ok(rect.position.x >= view.position.x - 1.0 and rect.end.x <= view.end.x + 1.0,
			"no horizontal clipping: " + str(node.get_path()))
	if node is Label:
		t.ok(node.get_visible_line_count() == node.get_line_count(), "all text lines visible: " + str(node.get_path()))
		t.ok(node.get_combined_minimum_size().y <= node.size.y + 1.0, "text height fits: " + str(node.get_path()))
	for child in node.get_children():
		_scan(t, child, view)
