extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("goal guard")
	t.test("shield control, fast interception, scoring and restart")
	var cfg := MatchConfig.build("goal_guard", ["fanoos", "mowja", "ramla", "nabta"], 1, 1, 72)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	game.on_round_start()
	game.tick(0.0)
	t.equal(game.side_for(0), 2, "local keeper starts on the near goal")
	t.equal(game.paddles.size(), 4, "every keeper has a visible shield")
	t.equal(scene.ctx.definition.control_profile, ControlProfile.Kind.KEEPER, "single-stick keeper controls")
	t.ok(not ControlProfile.shows_aim_stick(ControlProfile.Kind.KEEPER), "no redundant aim stick")
	var touch := TouchSource.new()
	host.add_child(touch)
	touch.setup(0, scene.ctx.definition)
	for view in [Vector2(720, 1560), Vector2(1920, 1080)]:
		touch.size = view
		for layout in [
			{"touch_keeper_move_side": "left", "touch_keeper_dash_side": "right", "touch_keeper_return_side": "right"},
			{"touch_keeper_move_side": "right", "touch_keeper_dash_side": "left", "touch_keeper_return_side": "left"},
			{"touch_keeper_move_side": "left", "touch_keeper_dash_side": "left", "touch_keeper_return_side": "right"},
			{"touch_keeper_move_side": "right", "touch_keeper_dash_side": "right", "touch_keeper_return_side": "left"},
		]:
			for key in layout:
				UserSettings.set_value(key, layout[key])
			var steering_on_right: bool = layout["touch_keeper_move_side"] == "right"
			t.equal(touch._stick_centre().x > view.x * 0.5, steering_on_right, "steering follows its selected side")
			for index in touch.buttons.size():
				var p := touch._button_centre(index)
				var setting := "touch_keeper_return_side" if touch.buttons[index] == "attack" else "touch_keeper_dash_side"
				t.equal(p.x > view.x * 0.5, layout[setting] == "right", "action follows its selected side")
				t.ok(p.distance_to(touch._stick_centre()) > 184.0, "buttons do not overlap steering")
				t.equal(touch._button_hit(p), index, "button hit area matches drawing")
				t.ok(Rect2(Vector2.ZERO, view).has_point(p), "button remains inside viewport")
	var f: Fighter = scene.ctx.fighter(0)
	var ball: GameBall = game.balls[0]
	var shield: Vector3 = game.paddles[0].global_position
	ball.launch(shield + Vector3.FORWARD * 0.9, Vector3.BACK, 26.0)
	game._defend_ball(ball, 1.0 / 30.0)
	t.ok(ball.velocity.z < 0, "fast incoming ball is intercepted before crossing shield")
	t.equal(ball.last_toucher, 0, "save credited to keeper")
	t.equal(int(scene.ctx.details[0].get("saves", 0)), 1, "actual saves counted")
	f._attack_time = 0.2
	ball.launch(shield + Vector3.FORWARD * 0.9, Vector3.BACK, 10.0)
	game._defend_ball(ball, 0.05)
	t.near(game.charges[0], 0.0, 0.001, "power shot consumes charge")
	t.near(ball.speed, 15.0, 0.001, "charged strike accelerates ball")
	ball.launch(shield + Vector3.RIGHT * 5.0 + Vector3.FORWARD * 0.9, Vector3.BACK, 26.0)
	game._defend_ball(ball, 0.05)
	t.ok(ball.velocity.z > 0, "off-target shot can pass keeper")
	scene.ctx.set_score(0, 1)
	game._on_goal(ball, 2)
	t.equal(scene.ctx.scores[0], 0, "last conceded goal consumes last point")
	t.ok(not f.alive and not scene.ctx.is_alive(0), "zero-point keeper is eliminated")
	game._on_goal(ball, 2)
	t.equal(scene.ctx.scores[0], 0, "eliminated goal cannot lose extra points")
	game.on_round_start()
	t.equal(scene.ctx.scores[0], 12, "round reset restores points")
	t.ok(scene.ctx.is_alive(0) and f.alive, "round reset revives keeper")
	t.equal(game.balls.size(), 1, "round reset restores a single ball")
	game._spawn_ball(true)
	var heavy: GameBall = game.balls.back()
	t.ok(heavy.max_speed < ball.max_speed, "heavy ball trades speed for damage")
	game._on_goal(heavy, 2)
	t.equal(scene.ctx.scores[0], 10, "heavy goal costs two points")
	touch.queue_free()
	UserSettings.set_value("touch_keeper_move_side", "left")
	UserSettings.set_value("touch_keeper_dash_side", "right")
	UserSettings.set_value("touch_keeper_return_side", "right")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
