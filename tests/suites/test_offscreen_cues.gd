extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("offscreen player cues")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	host.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	var bounds := Rect2(40, 180, 1200, 340)
	for projection in [Camera3D.PROJECTION_PERSPECTIVE, Camera3D.PROJECTION_ORTHOGONAL]:
		camera.projection = projection
		t.test("projection %s visible and behind points" % projection)
		t.ok(OffscreenPlayerCue.project(camera, Vector3(0, 0, -10), bounds).is_empty(), "visible player has no edge marker")
		var behind := OffscreenPlayerCue.project(camera, Vector3(0, 0, 10), bounds)
		t.ok(not behind.is_empty(), "behind-camera player retains a recovery cue")
		t.ok(behind.direction.y > 0.0, "straight behind defaults to bottom, not a NaN direction")
		var distant := OffscreenPlayerCue.project(camera, Vector3(0, 0, -camera.far * 2.0), bounds)
		t.ok(not distant.is_empty(), "a player clipped by the far plane is not treated as visible")
		t.ok(distant.direction.y < 0.0, "straight ahead but distant points forward, not backward")
		for position in [Vector3(100, 0, -10), Vector3(-100, 0, -10), Vector3(0, 100, -10), Vector3(100, 100, 10)]:
			var cue := OffscreenPlayerCue.project(camera, position, bounds)
			t.ok(not cue.is_empty(), "outside viewport has a cue")
			t.ok(bounds.grow(0.01).has_point(cue.position), "cue stays inside HUD-safe bounds")
			t.ok(cue.direction.is_finite() and is_equal_approx(cue.direction.length(), 1.0), "arrow is normalized")
	viewport.size = Vector2i(720, 1280)
	bounds = Rect2(40, 480, 640, 360)
	var portrait := OffscreenPlayerCue.project(camera, Vector3(100, 0, -10), bounds)
	t.ok(bounds.grow(0.01).has_point(portrait.position), "portrait layout uses its own safe rectangle")
	t.ok(portrait.direction.x > 0.0, "right target points right")
	t.ok(OffscreenPlayerCue.project(camera, Vector3.ZERO, Rect2()).is_empty(), "crowded layout never produces invalid positions")
	var grouped: Array[Dictionary] = []
	for slot in 4:
		grouped.append(portrait.duplicate())
	OffscreenPlayerCue.separate(grouped, bounds)
	for first in 4:
		t.ok(not grouped[first].is_empty(), "four cues fit on the portrait edge")
		for second in range(first + 1, 4):
			t.ok(grouped[first].position.distance_to(grouped[second].position) >= 56.0, "same-edge player symbols do not overlap")
	camera.position = Vector3(10, 0, 0)
	camera.rotation.y = PI * 0.5
	t.ok(OffscreenPlayerCue.project(camera, Vector3.ZERO, bounds).is_empty(), "projection follows current camera transform, including headless")
	var context := MatchContext.new()
	var fighter := Fighter.new()
	viewport.add_child(fighter)
	context.fighters = [fighter]
	context.alive = [true]
	context.phase = MatchPhase.P.PLAYING
	t.ok(OffscreenPlayerCue.eligible(context, 0), "living player in a live round is eligible")
	fighter.hide()
	t.ok(not OffscreenPlayerCue.eligible(context, 0), "hidden player location is not disclosed")
	fighter.show()
	context.alive[0] = false
	t.ok(not OffscreenPlayerCue.eligible(context, 0), "eliminated player has no recovery cue")
	context.alive[0] = true
	context.phase = MatchPhase.P.RESULTS
	t.ok(not OffscreenPlayerCue.eligible(context, 0), "results do not retain stale cues")
	context.phase = MatchPhase.P.PLAYING
	t.ok(not OffscreenPlayerCue.eligible(context, 2), "missing slot is safe")
	var source := TouchSource.new()
	host.add_child(source)
	source.size = Vector2(720, 1280)
	source.position = Vector2(30, 20)
	source.profile = ControlProfile.Kind.MOVEMENT_ACTION
	source.buttons.assign(["attack", "dash"])
	source._scale = 1.25
	var previous = UserSettings.get_value("touch_positions")
	UserSettings.set_value("touch_positions", {source.layout_key(): {"move": [0.25, 0.65], "button_attack": [0.8, 0.5]}})
	var rects := source.control_rects()
	t.equal(rects.size(), 3, "only the actual movement and action controls reserve space")
	t.ok(rects[0].get_center().is_equal_approx(source.global_position + source._stick_centre()), "moved joystick uses current saved layout and canvas translation")
	t.near(rects[0].size.x, TouchSource.STICK_RADIUS * 2.5, 0.01, "control enlargement is included in the safe bounds")
	t.ok(rects[1].get_center().is_equal_approx(source.global_position + source._button_centre(0)), "moved action button reserves its current position")
	UserSettings.set_value("touch_positions", previous)
	source.free()
	viewport.queue_free()
	await host.get_tree().process_frame
