extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("sky court")
	var cfg := MatchConfig.build("sky_court", ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 93)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	game._cycle = 0.01
	game._tick_hazard(0.02)
	t.ok(game._warn > 0, "cycle starts a warning")
	t.ok(game._warning_engine >= 0 and game._warning_engine < 4, "warning selects an existing engine")
	game._tick_hazard(0.09)
	game._tick_platform(0.09)
	var engine: Node3D = game._engines[game._warning_engine]
	t.ok(engine.scale.x < 1.0, "warning visibly pulses selected engine")
	var scale_before := engine.scale
	await host.get_tree().create_timer(0.25).timeout
	t.equal(engine.scale, scale_before, "warning does not animate while simulation is paused")
	game._warn = 0
	game._start_tilt(scene.arena)
	game._tick_platform(0.25)
	var rotation: Quaternion = scene.arena.quaternion
	t.ok(rotation.angle_to(Quaternion.IDENTITY) > 0.01, "platform visibly banks")
	t.ok(game._surface_height(scene.arena.global_position + game._down * 5.0) < scene.arena.global_position.y,
		"slope force points toward the lower side of the surface")
	for mesh in game._court_transforms:
		if not game._engines.has(mesh):
			t.ok(mesh.global_transform.is_equal_approx(scene.arena.global_transform * game._court_transforms[mesh]), "court markings follow tilted floor")
	for fighter: Fighter in scene.ctx.fighters:
		t.near(fighter.global_position.y, game._surface_height(fighter.global_position) + 0.9, 0.001, "keeper stays above tilted surface")
	await host.get_tree().create_timer(0.25).timeout
	t.ok(scene.arena.quaternion.is_equal_approx(rotation), "banking does not advance while paused")
	game.on_round_start()
	t.ok(scene.arena.quaternion.is_equal_approx(Quaternion.IDENTITY), "restart levels platform immediately")
	t.equal(game._down, Vector3.ZERO, "restart removes stale downhill direction")
	for e: Node3D in game._engines:
		t.equal(e.scale, Vector3.ONE, "restart clears engine pulses")
	await host.get_tree().create_timer(0.6).timeout
	t.ok(scene.arena.quaternion.is_equal_approx(Quaternion.IDENTITY), "no old tween can tilt restarted court")
	for fps in [30, 60, 120]:
		game._down = Vector3(1, 0, 1).normalized()
		game._tilting = 4.0
		game._bank = 0
		for i in fps / 2:
			game._tick_platform(1.0 / fps)
		t.near(scene.arena.quaternion.angle_to(Quaternion.IDENTITY), game.TILT_ANGLE, 0.0001, "same full tilt at every simulation rate")
		game._level_out()
		for i in fps:
			game._tick_platform(1.0 / fps)
		t.ok(scene.arena.quaternion.is_equal_approx(Quaternion.IDENTITY), "platform returns to level")
	var ball: GameBall = game.balls[0]
	game._down = Vector3.RIGHT
	ball.launch(Vector3(0, 0.9, 0), Vector3.RIGHT, 9.0)
	game._apply_slope(0.1)
	t.near(ball.speed, 9.0 + game.TILT_PULL * 0.1, 0.001, "downhill force updates retained speed")
	ball.tick(0.01)
	t.ok(ball.speed > 9.0, "ball normalization cannot discard slope acceleration")
	game._apply_slope(100.0)
	t.ok(ball.speed <= ball.max_speed, "slope cannot exceed ball speed limit")
	game._tilting = 4.0
	game._tick_platform(0.5)
	t.near(ball.global_position.y, game._surface_height(ball.global_position) + 0.9, 0.001, "ball stays above tilted surface")
	game.cleanup()
	t.ok(scene.arena.quaternion.is_equal_approx(Quaternion.IDENTITY), "cleanup leaves no tilted arena")
	t.equal(game._engines.size(), 0, "cleanup releases engine references")
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	host.add_child(viewport)
	var camera := ArenaCamera.new()
	viewport.add_child(camera)
	camera.set_process(false)
	camera.arena = scene.arena
	for view in [Vector2i(720, 1280), Vector2i(1280, 720)]:
		viewport.size = view
		camera.keep_aspect = Camera3D.KEEP_WIDTH if view.x < view.y else Camera3D.KEEP_HEIGHT
		var hud_bottom := 420.0 if view.x < view.y else 120.0
		camera.shared_hud_bottom = func(): return hud_bottom
		for touches in [0, 1, 2, 3, 4]:
			camera.shared_touch_count = touches
			camera._frame_court(Vector2(view))
			var bottom := float(view.y) * 0.95
			if touches > 1:
				bottom = TouchSource.party_region(Vector2(view), 0, touches).position.y - view.y * 0.02
			elif touches == 1:
				bottom = view.y * (0.76 if view.x < view.y else 0.80)
			for x in [-scene.arena.def.radius, scene.arena.def.radius]:
				for z in [-scene.arena.def.radius, scene.arena.def.radius]:
					for height in [-1.0, 3.0]:
						var pixel := camera.unproject_position(scene.arena.global_position + Vector3(x, height, z))
						t.ok(pixel.x >= 0 and pixel.x <= view.x, "court remains inside viewport width")
						t.ok(pixel.y >= hud_bottom and pixel.y <= bottom, "court stays clear of HUD and touch controls")
	viewport.queue_free()
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
