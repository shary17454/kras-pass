extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("safe camera layout")
	var window := host.get_window()
	var old_size := window.size
	var old_scale := window.content_scale_size
	var old_mobile := Platform.is_mobile
	var old_safe := Platform.safe_area
	var old_last: Rect2i = Platform._last_safe
	var old_pane: Rect2 = Platform._native_pane
	var old_process := Platform.is_processing()
	var old_settings := UserSettings.snapshot()
	var connections := EventBus.camera_shake_requested.get_connections().size()
	Platform.set_process(false)
	Platform.is_mobile = true
	# No match scene, rendering, physics, HUD or input fixtures are needed.
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	host.add_child(viewport)
	var arena := Arena.new()
	arena.def = ArenaDef.new()
	arena.def.shape = "square"
	viewport.add_child(arena)
	arena.position = Vector3(4, 0, -3)
	var camera := ArenaCamera.new()
	viewport.add_child(camera)
	camera.set_process(false)
	camera.arena = arena
	for offset in [Vector3(-4, 0, -4), Vector3(4, 0, 4)]:
		var target := Node3D.new()
		viewport.add_child(target)
		target.position = arena.position + offset
		camera.targets.append(target)
	for resolution in [Vector2i(1920, 1080), Vector2i(1080, 1920)]:
		window.content_scale_size = resolution
		window.size = resolution
		viewport.size = resolution
		await host.get_tree().process_frame
		var view := Vector2(resolution)
		camera.keep_aspect = Camera3D.KEEP_WIDTH if view.x < view.y else Camera3D.KEEP_HEIGHT
		t.equal(viewport.get_visible_rect().size, view, "projection viewport has exact test dimensions")
		for normalized in [Rect2(0, 0, 1, 1), Rect2(0, 0, 0.49, 1), Rect2(0.51, 0, 0.49, 1), Rect2(0, 0.51, 1, 0.49)]:
			var pane := Rect2(normalized.position * view, normalized.size * view)
			Platform._native_pane = normalized
			Platform.safe_area = Rect2i(pane)
			# Integer native geometry can round a fractional boundary by one pixel.
			var inset := Platform.safe_insets()
			pane = Rect2(Vector2(inset.x, inset.y), view - Vector2(inset.x + inset.z, inset.y + inset.w))
			for count in [0, 1, 2, 4]:
				camera.shared_touch_count = count
				for with_hud in [false, true]:
					t.test("%s pane=%s touch=%d hud=%s" % [resolution, normalized, count, with_hud])
					var hud_bottom := pane.position.y + pane.size.y * 0.18
					camera.shared_hud_bottom = func(): return hud_bottom
					if not with_hud:
						camera.shared_hud_bottom = Callable()
					var safe := camera.arena_safe_rect(view)
					t.ok(pane.grow(1).encloses(safe), "arena safe rectangle stays inside the selected pane")
					if count > 1:
						var controls := pane.position.y + TouchSource.party_region(pane.size, 0, count).position.y
						t.near(safe.end.y, controls - 20.0, 0.01, "arena reserves pane-local party controls")
					camera.mode = ArenaCamera.Mode.COURT
					camera._frame_court(view)
					_check_court(t, camera, pane, hud_bottom, with_hud)
					if normalized == Rect2(0, 0, 1, 1):
						_check_fullscreen_court(t, camera, view, hud_bottom, with_hud)
					camera.mode = ArenaCamera.Mode.WORLD
					camera.size = 1.0
					camera._frame_shared_world(1.0, view)
					_check_shared_world(t, camera, pane, hud_bottom, with_hud)
					if normalized == Rect2(0, 0, 1, 1):
						_check_fullscreen_world(t, camera, view, hud_bottom, with_hud)
					camera.mode = ArenaCamera.Mode.ARENA
					camera.projection = Camera3D.PROJECTION_PERSPECTIVE
					camera.focus = arena.global_position
					camera._apply(1.0, 0.0)
					_inside(t, camera, _court_points(arena, 0.0, 3.0), safe, "perspective arena rim and player height")
					_check_follow(t, camera, pane, view)
	viewport.free()
	window.content_scale_size = old_scale
	window.size = old_size
	Platform.is_mobile = old_mobile
	Platform._native_pane = old_pane
	Platform.safe_area = old_safe
	Platform._last_safe = old_last
	Platform.set_process(old_process)
	t.equal(window.size, old_size, "window size fixture restored")
	t.equal(window.content_scale_size, old_scale, "logical viewport fixture restored")
	t.equal(Platform.safe_area, old_safe, "native safe-area fixture restored")
	t.equal(Platform._native_pane, old_pane, "native pane fixture restored")
	t.equal(UserSettings.snapshot(), old_settings, "camera tests leave settings unchanged")
	t.equal(EventBus.camera_shake_requested.get_connections().size(), connections, "camera shake connections do not leak")


func _check_follow(t: TestHarness, camera: ArenaCamera, pane: Rect2, view: Vector2) -> void:
	var subject := camera.arena.global_position + Vector3.UP
	for offset in [Vector3(0, 8, 12), Vector3(12, 6, 0)]:
		camera.global_position = subject + offset
		camera.look_at(subject + Vector3(0, 0, -3), Vector3.UP)
		var original := camera.global_transform
		var relative := (camera.unproject_position(subject) / view).clamp(Vector2(0.15, 0.15), Vector2(0.85, 0.85))
		camera._fit_follow_pane(subject, view)
		var pixel := camera.unproject_position(subject)
		t.ok(pixel.distance_to(pane.position + relative * pane.size) < 0.1, "follow subject retains pane-relative screen position")
		t.ok(pane.has_point(pixel), "follow subject remains inside unobscured pane")
		t.equal(camera.global_position, original.origin, "follow fitting cannot move collision-tested camera origin")
		if pane.is_equal_approx(Rect2(Vector2.ZERO, view)):
			t.ok(camera.global_basis.is_equal_approx(original.basis), "full-screen follow orientation remains unchanged")


func _check_court(t: TestHarness, camera: ArenaCamera, pane: Rect2, hud: float, with_hud: bool) -> void:
	var top := pane.position.y + pane.size.y * 0.05
	if with_hud:
		top = clampf(hud + 20.0, top, pane.position.y + pane.size.y * 0.70)
	var bottom := pane.position.y + pane.size.y * 0.95
	if camera.shared_touch_count > 1:
		bottom = pane.position.y + TouchSource.party_region(pane.size, 0, camera.shared_touch_count).position.y - pane.size.y * 0.02
	elif camera.shared_touch_count == 1:
		bottom = pane.position.y + pane.size.y * (0.76 if pane.size.x < pane.size.y else 0.80)
	var safe := Rect2(pane.position.x + pane.size.x * 0.04, top, pane.size.x * 0.92, bottom - top)
	var points := _court_points(camera.arena, 1.4, 0.0)
	points.append_array(_court_points(camera.arena, 0.0, 3.0))
	_inside(t, camera, points, safe, "orthographic banked court and keeper height")
	var pixel := camera.unproject_position(camera.arena.global_position)
	t.near(pixel.x, pane.get_center().x, 0.1, "court is horizontally centered in pane")
	t.near(pixel.y, (top + bottom) * 0.5, 0.1, "court is vertically centered between HUD and controls")


func _check_shared_world(t: TestHarness, camera: ArenaCamera, pane: Rect2, hud: float, with_hud: bool) -> void:
	var top := pane.position.y + pane.size.y * (0.29 if pane.size.x < pane.size.y else 0.20)
	if with_hud:
		top = maxf(pane.position.y + pane.size.y * 0.12, hud + 30.0)
	var bottom := pane.end.y
	if camera.shared_touch_count > 1:
		bottom = pane.position.y + TouchSource.party_region(pane.size, 0, camera.shared_touch_count).position.y
	var safe := Rect2(pane.position.x + pane.size.x * 0.05, top + pane.size.y * 0.04, pane.size.x * 0.90, bottom - top - pane.size.y * 0.08)
	var points: Array[Vector3] = []
	for target in camera.targets:
		for x in [-2.0, 2.0]:
			for z in [-2.0, 2.0]:
				points.append(target.global_position + Vector3(x, 0, z))
	_inside(t, camera, points, safe, "shared-world vehicle bounds")
	var pixel := camera.unproject_position(camera.arena.global_position)
	t.near(pixel.x, pane.get_center().x, 0.1, "shared world is horizontally centered in pane")
	t.near(pixel.y, (top + bottom) * 0.5, 0.1, "shared world is vertically centered in pane")


func _check_fullscreen_court(t: TestHarness, camera: ArenaCamera, view: Vector2, hud: float, with_hud: bool) -> void:
	var aspect := view.x / view.y
	var top := clampf((hud + 20.0) / view.y, 0.05, 0.70) if with_hud else 0.05
	var bottom := 0.95
	if camera.shared_touch_count > 1:
		bottom = TouchSource.party_region(view, 0, camera.shared_touch_count).position.y / view.y - 0.02
	elif camera.shared_touch_count == 1:
		bottom = 0.76 if view.x < view.y else 0.80
	var diameter := camera.arena.def.radius * 2.0 + 2.8
	var height := diameter * absf(camera.global_basis.y.z) + 4.0 * absf(camera.global_basis.y.y)
	var world_height := maxf(diameter / (aspect * 0.92), height / maxf(0.10, bottom - top))
	t.near(camera.size, world_height * aspect if view.x < view.y else world_height, 0.001, "no-inset court zoom matches legacy math")
	var expected := camera.arena.global_position + Vector3(0, 30, 17) + camera.global_basis.y * (((top + bottom) * 0.5 - 0.5) * world_height)
	t.ok(camera.global_position.distance_to(expected) < 0.001, "no-inset court transform matches legacy math")
	var arena_top := maxf(view.y * 0.06, hud + 24.0) if with_hud else view.y * 0.06
	var arena_bottom := view.y * 0.92
	if camera.shared_touch_count > 1:
		arena_bottom = TouchSource.party_region(view, 0, camera.shared_touch_count).position.y - 20.0
	elif camera.shared_touch_count == 1:
		arena_bottom = view.y * (0.76 if view.x < view.y else 0.80)
	var expected_safe := Rect2(view.x * 0.06, arena_top, view.x * 0.88, arena_bottom - arena_top)
	t.ok(camera.arena_safe_rect(view).is_equal_approx(expected_safe), "no-inset arena safe rectangle matches legacy math")


func _check_fullscreen_world(t: TestHarness, camera: ArenaCamera, view: Vector2, hud: float, with_hud: bool) -> void:
	var aspect := view.x / view.y
	var top := 0.29 if view.x < view.y else 0.20
	if with_hud:
		top = maxf(0.12, (hud + 30.0) / view.y)
	var bottom := 1.0
	if camera.shared_touch_count > 1:
		bottom = TouchSource.party_region(view, 0, camera.shared_touch_count).position.y / view.y
	var width := clampf(maxf(18.0 / 0.90, 18.0 * aspect / maxf(0.1, bottom - top - 0.08)), 24.0, 80.0)
	var height := width / aspect
	t.near(camera.size, width if view.x < view.y else height, 0.001, "no-inset shared-world zoom matches legacy math")
	var expected := camera.arena.global_position + Vector3(0, maxf(160.0, width), (0.5 - (top + bottom) * 0.5) * height)
	t.ok(camera.global_position.distance_to(expected) < 0.001, "no-inset shared-world transform matches legacy math")


func _court_points(arena: Arena, bank: float, height: float) -> Array[Vector3]:
	var points: Array[Vector3] = []
	var radius := arena.current_radius + bank
	for x in [-radius, radius]:
		for z in [-radius, radius]:
			for y in [0.0, height]:
				points.append(arena.global_position + Vector3(x, y, z))
	return points


func _inside(t: TestHarness, camera: Camera3D, points: Array[Vector3], safe: Rect2, name: String) -> void:
	var bounds := Rect2(camera.unproject_position(points[0]), Vector2.ZERO)
	var in_front := true
	for point in points:
		in_front = in_front and not camera.is_position_behind(point)
		bounds = bounds.expand(camera.unproject_position(point))
	t.ok(in_front and bounds.is_finite() and safe.grow(1.0).encloses(bounds), "%s: safe=%s projected=%s" % [name, safe, bounds])
