extends RefCounted


class DrawProbe extends TouchSource:
	var observed_calls := 0
	var actual_data := {}

	func party_identity_draw_data() -> Dictionary:
		observed_calls += 1
		return actual_data


class ObstacleSource extends TouchSource:
	var actual_rects: Array[Rect2] = []

	func control_rects() -> Array[Rect2]:
		return actual_rects


func run(t: TestHarness, host: Node) -> void:
	t.suite("party touch identity contrast")
	var before_root := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--identity-before-root="):
			before_root = argument.trim_prefix("--identity-before-root=")
	if not before_root.is_empty():
		_before_pixels(t, before_root)
		return
	var source := TouchSource.new()
	t.ok(source.has_method("party_identity_draw_data"), "actual party draw exposes its opaque identity layout")
	source.free()
	await _matrix(t, host)
	_narrow_and_custom_targets(t)
	_dynamic_origins(t)
	await _draw_consumes_helper(t, host)


func _matrix(t: TestHarness, host: Node) -> void:
	var saved := UserSettings.snapshot()
	var old_size := host.get_window().size
	var old_locale := Loc.locale
	var rows: Array = []
	for dark in [false, true]:
		for high_contrast in [false, true]:
			UserSettings.set_value("appearance", "dark" if dark else "light")
			UserSettings.set_value("high_contrast", high_contrast)
			await host.get_tree().process_frame
			for locale in ["ar", "en"]:
				Loc.set_locale(locale)
				for resolution in [Vector2i(1280, 720), Vector2i(540, 960)]:
					host.get_window().size = resolution
					await host.get_tree().process_frame
					for left in [false, true]:
						UserSettings.set_value("touch_left_handed", left)
						for humans in range(1, 5):
							var layer := CanvasLayer.new()
							host.add_child(layer)
							for slot in humans:
								var control := TouchSource.new()
								layer.add_child(control)
								control.setup(slot, Registry.minigame("duel_pit"), slot, humans)
								for opacity in [0.05, 0.15, 0.5, 1.0]:
									UserSettings.set_value("touch_opacity", opacity)
									var old_rects := control.control_rects()
									var old_region := control.get_global_rect()
									var old_bits := control._bits
									var old_scale := control._scale
									var data: Dictionary = control.call("party_identity_draw_data")
									t.equal(control.control_rects(), old_rects, "identity never repositions input controls")
									t.equal(control.get_global_rect(), old_region, "identity never resizes a party region")
									t.equal(control._bits, old_bits, "identity never changes input state")
									t.equal(control._scale, old_scale, "identity never rescales the controls")
									t.near(control._opacity, opacity, 0.00001, "button opacity setting is not strengthened or weakened")
									if humans == 1:
										t.ok(data.is_empty(), "single-player controls do not gain a party badge")
										continue
									t.ok(not data.is_empty(), "ordinary duel party cell retains a visible identity")
									if data.is_empty():
										continue
									var bounds: Rect2 = data.bounds
									var text_bounds: Rect2 = data.text_bounds
									var background: Color = data.background
									var foreground: Color = data.foreground
									var style: StyleBoxFlat = data.style
									t.ok(Rect2(Vector2.ZERO, control.size).encloses(bounds), "badge stays within its own party region")
									t.ok(bounds.size.y <= 44.0, "badge remains a compact identity rather than a panel")
									t.ok(bounds.encloses(text_bounds), "actual font metrics fit the identity backing")
									t.equal(data.text, "P%d %s" % [slot + 1, PlayerConfig.SYMBOLS[slot]], "identity retains number and unique symbol")
									t.near(background.a, 1.0, 0.00001, "backing cannot expose arbitrary world colors")
									t.near(foreground.a, 1.0, 0.00001, "identity ink is independent of touch opacity")
									t.equal(style.bg_color, background, "draw style consumes the tested background")
									t.equal(style.border_color, data.border, "draw style consumes the tested neutral border")
									t.equal(data.border, Color(UIKit.dim_color(), 1.0), "badge never invents misleading character colors")
									var contrast := _contrast(foreground, background)
									t.ok(contrast >= 4.5, "actual identity ink reaches 4.5:1 in every theme")
									t.ok(_contrast(data.border, background) >= 4.5, "neutral border remains readable against the backing")
									for world in [Color.BLACK, Color.WHITE, Color("#4d3e3b"), foreground, background,
											Color.RED, Color.GREEN, Color.BLUE, Color(0.5, 0.5, 0.5)]:
										var backing_on_world: Color = world.blend(background)
										var ink_on_backing: Color = backing_on_world.blend(foreground)
										t.equal(backing_on_world, background, "opaque backing mathematically eliminates world dependence")
										t.ok(_contrast(ink_on_backing, backing_on_world) >= 4.5, "composited identity retains contrast")
									for rect in control.control_rects():
										t.ok(not bounds.intersects(Rect2(rect.position - control.global_position, rect.size)), "badge does not cover a duel input target")
									rows.append({"dark": dark, "high_contrast": high_contrast, "locale": locale,
										"resolution": [resolution.x, resolution.y], "left": left, "humans": humans,
										"slot": slot, "opacity": opacity, "contrast": contrast,
										"border_contrast": _contrast(data.border, background),
										"bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
										"foreground": foreground.to_html(), "background": background.to_html()})
							layer.free()
	var output := FileAccess.open(SaveSystem.storage_root.path_join("identity-contrast-matrix.json"), FileAccess.WRITE)
	t.ok(output != null, "contrast and bounds matrix is retained")
	if output != null:
		output.store_string(JSON.stringify({"rows": rows}, "  "))
		output.close()
	host.get_window().size = old_size
	Loc.set_locale(old_locale)
	for key in saved:
		UserSettings.set_value(key, saved[key])
	await host.get_tree().process_frame


func _narrow_and_custom_targets(t: TestHarness) -> void:
	t.test("narrow party cells omit identities rather than overflowing")
	var probe := ObstacleSource.new()
	probe._font = UIKit.font_bold()
	probe.touch_count = 4
	for width in [17.0, 24.0, 40.0, 56.0, 64.0, 80.0, 96.0, 320.0]:
		for height in [20.0, 36.0, 40.0, 216.0]:
			probe.size = Vector2(width, height)
			var data := probe.party_identity_draw_data()
			if not data.is_empty():
				t.ok(Rect2(Vector2.ZERO, probe.size).encloses(data.bounds), "narrow badge is fully inside the cell")
				t.ok(data.bounds.encloses(data.text_bounds), "narrow text fits its own backing")
			else:
				t.ok(true, "unsafe narrow cell omits the badge")
	probe.size = Vector2(320, 216)
	var clear := probe.party_identity_draw_data()
	t.ok(not clear.is_empty(), "ordinary unobstructed party cell keeps its identity")
	if clear.is_empty():
		probe.free()
		return
	var saved_positions = UserSettings.get_value("touch_positions").duplicate(true)
	var saved_scale = UserSettings.get_value("touch_scale")
	var saved_hand = UserSettings.get_value("touch_left_handed")
	for left in [false, true]:
		t.test("custom input at header is retained; left=%s" % left)
		UserSettings.set_value("touch_scale", 1.0)
		UserSettings.set_value("touch_left_handed", left)
		var custom := TouchSource.new()
		custom.profile = Registry.minigame("duel_pit").control_profile
		custom.buttons = ControlProfile.buttons_for(custom.profile, Registry.minigame("duel_pit").control_hints)
		custom.size = Vector2(320, 216)
		custom._read_settings()
		# Party ignores custom settings today. Feed real custom single-source
		# rectangles through the same draw contract, without changing that policy.
		UserSettings.set_value("touch_positions", {custom.layout_key(): {"move": [0.5, 0.0]}})
		var targets := custom.control_rects()
		var header: Rect2 = clear.bounds
		t.ok(header.intersects(targets[0]), "actual clamped custom stick overlaps the proposed header")
		probe.actual_rects = targets
		var snapshot := targets.duplicate()
		t.ok(probe.party_identity_draw_data().is_empty(), "badge is omitted rather than covering a custom target")
		t.equal(custom.control_rects(), snapshot, "custom target stays where the user placed it")
		t.equal(probe.actual_rects, snapshot, "draw helper never clamps or moves input rectangles")
		custom.free()
	UserSettings.set_value("touch_positions", saved_positions)
	UserSettings.set_value("touch_scale", saved_scale)
	UserSettings.set_value("touch_left_handed", saved_hand)
	probe.free()


func _dynamic_origins(t: TestHarness) -> void:
	var saved_hand = UserSettings.get_value("touch_left_handed")
	var saved_positions = UserSettings.get_value("touch_positions").duplicate(true)
	var saved_scale = UserSettings.get_value("touch_scale")
	UserSettings.set_value("touch_scale", 1.0)
	UserSettings.set_value("touch_positions", {})
	var cases := 0
	for resolution in [Vector2(1280, 720), Vector2(540, 960)]:
		for humans in [2, 3, 4]:
			for left in [false, true]:
				UserSettings.set_value("touch_left_handed", left)
				for profile in [ControlProfile.Kind.DUAL_ACTION, ControlProfile.Kind.MEMORY,
						ControlProfile.Kind.ATV, ControlProfile.Kind.AIM_AND_MOVE]:
					var source := TouchSource.new()
					source.profile = profile
					source._font = UIKit.font_bold()
					source._haptics = false
					source.touch_count = humans
					source.position = Vector2(37, 59)
					source.size = TouchSource.party_region(resolution, 0, humans).size
					source._read_settings()
					for kind in ["move", "aim"] if profile == ControlProfile.Kind.AIM_AND_MOVE else ["move"]:
						t.test("dynamic %s humans=%d size=%s left=%s profile=%d" % [kind, humans, resolution, left, profile])
						var clear := source.party_identity_draw_data()
						t.ok(not clear.is_empty(), "unheld stick leaves the ordinary identity visible")
						if clear.is_empty():
							continue
						var header: Rect2 = clear.bounds
						var on_right := source._move_on_right() if kind == "move" else not source._move_on_right()
						var x := source.size.x * 0.5 + (8.0 if on_right else -8.0)
						var radius := TouchSource.STICK_RADIUS * source._scale \
							* (ControlProfile.stick_scale(profile) if kind == "move" else 1.0)
						var fixed := source.control_rects()
						var point := Vector2(x, header.get_center().y)
						source._handle_press(17, point, true)
						t.ok(source._owners_has(kind), "real press assigns the intended dynamic stick owner")
						source._handle_drag(17, point + Vector2(0, radius * 0.6))
						_assert_active_identity_omitted(t, source, fixed)
						source._handle_press(17, point, false)
						t.ok(not source.party_identity_draw_data().is_empty(), "identity returns after the dynamic stick releases")
						t.ok(source._owners.is_empty(), "release retains ordinary ownership cleanup")
						# The base circle can be clear while its clamped knob reaches
						# into the header. Guard both primitives that _draw_stick paints.
						point = Vector2(x, header.end.y + radius + 4.0)
						source._handle_press(18, point, true)
						t.ok(not source.party_identity_draw_data().is_empty(), "a nearby but non-overlapping active origin keeps the identity")
						source._handle_drag(18, point - Vector2(0, radius * 2.0))
						_assert_active_identity_omitted(t, source, fixed)
						source._handle_press(18, point, false)
						t.ok(not source.party_identity_draw_data().is_empty(), "identity returns after the protruding knob releases")
						cases += 1
					source.free()
	t.equal(cases, 60, "all movement/aim/profile/count/orientation/hand cases completed")
	UserSettings.set_value("touch_left_handed", saved_hand)
	UserSettings.set_value("touch_positions", saved_positions)
	UserSettings.set_value("touch_scale", saved_scale)


func _assert_active_identity_omitted(t: TestHarness, source: TouchSource, fixed: Array[Rect2]) -> void:
	var owners := source._owners.duplicate(true)
	var before := [source._move_origin, source._move_knob, source._aim_origin, source._aim_knob,
		source._move, source._aim, source._bits, source.position, source.size, source._scale]
	t.ok(source.party_identity_draw_data().is_empty(), "active joystick drawing takes precedence over identity backing")
	t.equal(source.control_rects(), fixed, "visual guard does not rewrite static input rectangles")
	t.equal(source._owners, owners, "visual guard preserves touch ownership")
	t.equal([source._move_origin, source._move_knob, source._aim_origin, source._aim_knob,
		source._move, source._aim, source._bits, source.position, source.size, source._scale], before,
		"visual guard preserves live origin, knob, input vector and layout")


func _draw_consumes_helper(t: TestHarness, host: Node) -> void:
	for profile in [ControlProfile.Kind.MOVEMENT_ACTION, ControlProfile.Kind.REACTION]:
		var real := TouchSource.new()
		real._font = UIKit.font_bold()
		real.size = Vector2(320, 216)
		real.touch_count = 4
		real._read_settings()
		var data: Dictionary = real.call("party_identity_draw_data")
		t.ok(not data.is_empty(), "draw probe consumes actual nonempty identity data")
		real.free()
		var probe := DrawProbe.new()
		probe._font = UIKit.font_bold()
		probe.size = Vector2(320, 216)
		probe.touch_count = 4
		probe.profile = profile
		probe.actual_data = data
		host.add_child(probe)
		probe.queue_redraw()
		for frame in 3:
			await host.get_tree().process_frame
		t.greater(probe.observed_calls, 0, "actual _draw consumes the tested helper, including the reaction return path")
		probe.free()


func _before_pixels(t: TestHarness, root: String) -> void:
	var rows: Array = []
	for locale in ["ar", "en"]:
		for orientation in ["landscape", "portrait"]:
			var file := root.path_join("h4-%s/save/screenshots/duel_pit-%s.png" % [locale, orientation])
			var image := Image.load_from_file(file)
			t.ok(image != null and not image.is_empty(), "before image is the actual frozen viewport")
			if image == null or image.is_empty():
				continue
			for slot in 4:
				var box := Rect2i(120 + slot * 320, 510, 80, 34) if orientation == "landscape" \
					else Rect2i(95 + (slot % 2) * 270, 560 + int(slot / 2) * 202, 80, 40)
				var colors := {}
				var darkest := Color.WHITE
				for x in range(box.position.x, box.end.x):
					for y in range(box.position.y, box.end.y):
						var pixel := image.get_pixel(x, y)
						var key := pixel.to_rgba32()
						colors[key] = int(colors.get(key, 0)) + 1
						if _luminance(pixel) < _luminance(darkest):
							darkest = pixel
				var dominant := 0
				for key in colors:
					if dominant == 0 or int(colors[key]) > int(colors[dominant]):
						dominant = key
				var background := Color.hex(dominant)
				var contrast := _contrast(darkest, background)
				rows.append({"image": file, "slot": slot, "box": [box.position.x, box.position.y, box.size.x, box.size.y],
					"foreground": darkest.to_html(), "background": background.to_html(), "contrast": contrast})
				t.ok(contrast >= 4.5, "%s/%s P%d actual before caption must reach 4.5:1 (got %.4f)" % [
					locale, orientation, slot + 1, contrast])
	var output := FileAccess.open(SaveSystem.storage_root.path_join("before-contrast.json"), FileAccess.WRITE)
	t.ok(output != null, "before measurements are retained without editing images")
	if output != null:
		output.store_string(JSON.stringify({"rows": rows, "method": "darkest caption pixel versus modal backing pixel inside caption-only regions"}, "  "))
		output.close()


func _luminance(color: Color) -> float:
	var linear := color.srgb_to_linear()
	return linear.r * 0.2126 + linear.g * 0.7152 + linear.b * 0.0722


func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
