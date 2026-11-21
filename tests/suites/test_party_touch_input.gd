extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("party touch input")
	_multiple_screen_fingers(t)
	_multiple_steering_fingers(t)
	await _routing_matrix(t, host)


func _multiple_screen_fingers(t: TestHarness) -> void:
	t.test("reaction touch stays held until its last owning finger releases")
	var source := TouchSource.new()
	source.profile = ControlProfile.Kind.REACTION
	source.size = Vector2(720, 1280)
	source._haptics = false
	var point := source.size * 0.5
	source._handle_press(1, point, true)
	source._handle_press(2, point, true)
	source._handle_press(1, point, false)
	t.ok((source._bits & InputFrame.Btn.ATTACK) != 0, "a second reaction finger preserves the held action")
	source._handle_press(2, point, false)
	t.equal(source._bits, 0, "last reaction finger releases the action")
	source.free()


func _multiple_steering_fingers(t: TestHarness) -> void:
	t.test("steering aggregates all active pad owners")
	var source := TouchSource.new()
	source.profile = ControlProfile.Kind.STEERING
	source.size = Vector2(1280, 720)
	source._haptics = false
	var pads := source._steer_rects()
	source._handle_press(1, pads[0].get_center(), true)
	source._handle_press(2, pads[0].get_center(), true)
	source._handle_press(1, pads[0].get_center(), false)
	t.equal(source._steer, -1.0, "one released finger cannot cancel another held left pad")
	source._handle_press(2, pads[0].get_center(), false)
	t.equal(source._steer, 0.0, "last left owner releases steering")
	source._handle_press(3, pads[0].get_center(), true)
	source._handle_press(4, pads[1].get_center(), true)
	t.equal(source._steer, 0.0, "opposing steering pads cancel like opposing keyboard directions")
	source._handle_press(3, pads[0].get_center(), false)
	t.equal(source._steer, 1.0, "releasing left retains an already-held right pad")
	source._handle_press(4, pads[1].get_center(), false)
	t.equal(source._steer, 0.0, "last right owner releases steering")
	source._handle_press(5, pads[2].get_center(), true)
	source._handle_press(6, pads[2].get_center(), true)
	source._handle_press(5, pads[2].get_center(), false)
	t.equal(source._throttle, 1.0, "one released finger cannot cancel held throttle")
	source._handle_press(6, pads[2].get_center(), false)
	t.equal(source._throttle, 0.0, "last throttle owner releases acceleration")
	source.free()


func _routing_matrix(t: TestHarness, host: Node) -> void:
	var window := host.get_window()
	var old_size := window.size
	var saved := {}
	for key in ["touch_controls", "touch_left_handed", "touch_scale", "touch_positions", "vibration"]:
		saved[key] = UserSettings.get_value(key)
	UserSettings.set_value("touch_controls", "on")
	UserSettings.set_value("touch_scale", 1.0)
	UserSettings.set_value("touch_positions", {})
	UserSettings.set_value("vibration", false)
	InputRouter.clear_all()
	var cases := 0
	for game in Registry.all_minigames():
		for resolution in [Vector2i(540, 960), Vector2i(1280, 720)]:
			for humans in range(1, 5):
				for left_handed in [false, true]:
					t.test("%s humans=%d resolution=%s left_handed=%s" % [game.id, humans, resolution, left_handed])
					window.size = resolution
					UserSettings.set_value("touch_left_handed", left_handed)
					await host.get_tree().process_frame
					var layer := CanvasLayer.new()
					host.add_child(layer)
					var sources: Array[TouchSource] = []
					var points: Array[Vector2] = []
					for slot in humans:
						InputRouter.assign_touch(slot)
						var source := TouchSource.new()
						layer.add_child(source)
						source.setup(slot, game, slot, humans)
						sources.append(source)
					await _settle(host)
					for source in sources:
						_assert_bounds(t, source)
						points.append(_press_control(host.get_viewport(), source))
					await _settle(host)
					for source in sources:
						_assert_active(t, source)
					var multi_owner := ControlProfile.shows_steering(sources[0].profile) \
						or ControlProfile.full_screen_tap(sources[0].profile) != 0
					if multi_owner:
						_touch(host.get_viewport(), 4, points[0], true)
					_touch(host.get_viewport(), 0, points[0], false)
					await _settle(host)
					if multi_owner:
						_assert_active(t, sources[0])
						_touch(host.get_viewport(), 4, points[0], false)
						await _settle(host)
					t.ok(_neutral(InputRouter.frame(0)), "last owning finger clears only its own player's frame")
					for slot in range(1, humans):
						_assert_active(t, sources[slot])
					_press_control(host.get_viewport(), sources[0])
					await _settle(host)
					for source in sources:
						_assert_active(t, source)
					window.size = Vector2i(resolution.y, resolution.x)
					await _settle(host)
					for source in sources:
						t.ok(_neutral(InputRouter.frame(source.slot)), "rotation clears held input without a stuck action")
						t.ok(source._owners.is_empty(), "rotation clears obsolete touch owners")
						_assert_bounds(t, source)
					for slot in humans:
						_touch(host.get_viewport(), slot, points[slot], false)
					layer.queue_free()
					await host.get_tree().process_frame
					InputRouter.clear_all()
					cases += 1
	t.equal(cases, Registry.all_minigames().size() * 16, "every game/count/orientation/handedness case completed")
	print("PARTY_TOUCH_MATRIX games=%d cases=%d" % [Registry.all_minigames().size(), cases])
	window.size = old_size
	for key in saved:
		UserSettings.set_value(key, saved[key])
	await host.get_tree().process_frame


func _press_control(viewport: Viewport, source: TouchSource) -> Vector2:
	var point := source.global_position + source.size * 0.5
	if ControlProfile.shows_steering(source.profile):
		point = source.global_position + source._steer_rects()[2].get_center()
	elif not source.buttons.is_empty():
		point = source.global_position + source._button_centre(0)
	elif ControlProfile.shows_move_stick(source.profile):
		point = source.global_position + source._stick_centre()
	_touch(viewport, source.slot, point, true)
	if source.buttons.is_empty() and ControlProfile.shows_move_stick(source.profile):
		var drag := InputEventScreenDrag.new()
		drag.index = source.slot
		drag.position = point - Vector2(0, TouchSource.STICK_RADIUS * source._scale * 0.6)
		viewport.push_input(drag, true)
	return point


func _touch(viewport: Viewport, index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	viewport.push_input(event, true)


func _settle(host: Node) -> void:
	for frame in 3:
		await host.get_tree().physics_frame
	await host.get_tree().process_frame


func _assert_active(t: TestHarness, source: TouchSource) -> void:
	var frame := InputRouter.frame(source.slot)
	if ControlProfile.shows_steering(source.profile):
		t.ok(frame.move.y < -0.5, "throttle reaches its own player frame")
	elif ControlProfile.full_screen_tap(source.profile) != 0:
		t.ok(frame.held(ControlProfile.full_screen_tap(source.profile)), "reaction touch reaches its own player frame")
	elif not source.buttons.is_empty():
		t.ok(frame.held(ControlProfile.BUTTON_BITS[source.buttons[0]]), "declared action reaches its own player frame")
	else:
		t.ok(frame.move.y < -0.1, "movement drag reaches its own player frame")


func _assert_bounds(t: TestHarness, source: TouchSource) -> void:
	var region := source.get_global_rect().grow(1.0)
	for rect in source.control_rects():
		t.ok(region.encloses(rect), "control remains inside the owning player's region")


func _neutral(frame: InputFrame) -> bool:
	return frame.bits == 0 and frame.move.is_zero_approx() and frame.aim.is_zero_approx()
