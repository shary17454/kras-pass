extends RefCounted


class KeeperProbe extends "res://src/ai/brains/keeper_brain.gd":
	var observed: Dictionary
	var ball: GameBall
	var target := Vector3.INF
	func _most_dangerous_ball() -> GameBall:
		return ball
	func perceive_ball(_ball: GameBall) -> Dictionary:
		return observed
	func steer_to(point: Vector3, _urgency: float = 1.0) -> void:
		target = point


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
	_test_keeper_interception(t, scene)
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
	await _network_replica(t, host)
	await _terminal_goal_boundary(t, host)


func _terminal_goal_boundary(t: TestHarness, host: Node) -> void:
	t.test("later balls cannot concede after the last keeper has won")
	for game_id in ["goal_guard", "storm_heart"]:
		for count in [2, 3, 4]:
			var cfg := MatchConfig.build(game_id, ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 73)
			cfg.players.resize(count)
			var scene: Node = load("res://src/match/match_scene.gd").new()
			host.add_child(scene)
			scene.setup({"config": cfg, "on_finished": func(_r): pass})
			scene.set_physics_process(false)
			var game = scene.controller
			for first in count:
				for survivor in count:
					if first == survivor:
						continue
					game.on_round_start()
					for slot in count:
						scene.ctx.set_score(slot, 1 if slot in [first, survivor] else 0)
						if slot not in [first, survivor]:
							scene.ctx.eliminate(slot)
							scene.ctx.fighter(slot).alive = false
					var ball: GameBall = game.balls[0]
					game._on_goal(ball, game.side_for(first))
					t.ok(game.is_round_over(), "penultimate concession ends the keeper round")
					var before_details: Array = scene.ctx.details.duplicate(true)
					var generation := ball.launch_generation
					game._on_goal(ball, game.side_for(survivor))
					t.equal(scene.ctx.scores[survivor], 1, "later goal cannot erase the winner's retained point")
					t.ok(scene.ctx.is_alive(survivor), "terminal survivor is not eliminated by a later ball")
					t.equal(scene.ctx.details, before_details, "terminal goal cannot add a conceded event")
					t.equal(ball.launch_generation, generation, "terminal goal cannot relaunch a ball")
			scene.teardown()
			scene.queue_free()
			await host.get_tree().process_frame


func _test_keeper_interception(t: TestHarness, scene: Node) -> void:
	t.test("keepers predict crossing from observed trajectory on all four sides")
	for slot in 4:
		var brain := KeeperProbe.new()
		brain.controller = scene.controller
		brain.configure(slot, scene.ctx, 3, 819)
		brain.prediction = 1.0
		brain.risk = 0.0
		brain.ball = scene.controller.balls[0]
		brain.ball.velocity = Vector3(999, 0, 999)
		var normal: Vector3 = scene.controller.NORMALS[scene.controller.side_for(slot)]
		var axis: Vector3 = brain._goal_axis
		var pos: Vector3 = brain._goal_pos + normal * 8.0 - axis * 2.0
		var vel: Vector3 = -normal * 8.0 + axis * 6.0
		brain.observed = {"position": pos, "velocity": vel, "radius": brain.ball.visible_radius()}
		var paddle: Vector3 = scene.controller.paddles[slot].global_position
		var contact_time: float = ((paddle - pos).dot(normal) + brain.ball.radius) / vel.dot(normal)
		var contact_lane: float = (pos + vel * contact_time - brain._goal_pos).dot(axis)
		brain.decide(0.1)
		t.ok(brain.target.is_equal_approx(brain._goal_pos + axis * contact_lane), "intercept predicts sphere contact at the shield, not the player centre")
		brain.observed.velocity = normal * 8.0 + axis * 6.0
		brain.decide(0.1)
		t.ok(brain.target.is_equal_approx(brain._goal_pos - axis * 2.0), "departing ball does not produce a backwards-time crossing")
		brain.observed.velocity = axis * 6.0
		brain.decide(0.1)
		t.ok(brain.target.is_equal_approx(brain._goal_pos - axis * 2.0), "parallel trajectory has no invented arrival time")
		brain.observed.velocity = -normal * 8.0 + axis * 100.0
		brain.decide(0.1)
		var limit: float = scene.arena.def.radius - 2.0
		t.ok(brain.target.is_equal_approx(brain._goal_pos + axis * limit), "crossing outside lane is clamped to reachable court edge")
		brain.observed.velocity = vel
		brain.prediction = 0.0
		brain.decide(0.1)
		t.ok(brain.target.is_equal_approx(brain._goal_pos - axis * 1.7), "low-prediction tier retains its short observed horizon")
		brain.prediction = 1.0
		brain.risk = 1.0
		brain.observed = {"position": brain._goal_pos + normal * 2.0 - axis * 0.5,
			"velocity": -normal * 8.0 + axis * 6.0, "radius": brain.ball.visible_radius()}
		contact_time = ((paddle - Vector3(brain.observed.position)).dot(normal) + brain.ball.radius) / vel.dot(normal)
		contact_lane = (Vector3(brain.observed.position) + vel * contact_time - brain._goal_pos).dot(axis)
		brain.decide(0.1)
		t.ok(brain.target.is_equal_approx(brain._goal_pos + axis * contact_lane), "nearby sphere contact never draws keeper off its physically constrained lane")
		brain.controller = null


func _network_replica(t: TestHarness, host: Node) -> void:
	t.test("host ball snapshots render without guest scoring or simulation")
	var cfg := MatchConfig.build("goal_guard", ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 73)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	game.tick(0.0)
	game._spawn_ball(true)
	game.charges[0] = 0.25
	game.balls[0].global_position = Vector3(2, 0.9, 3)
	var replica = preload("res://src/net/match_replica.gd").new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	t.ok(replica.accept(packet, 4, "goal_guard"), "world survives JSON transport")
	for invalid_world in [null, {}, {"balls": [], "charges": [1, 1, 1, 1]}]:
		var invalid := packet.duplicate(true)
		invalid.world = invalid_world
		t.ok(not replica.accept(invalid, 4, "goal_guard"), "reject missing world state")
	for invalid_charge in [-0.1, 1.1, NAN, "1"]:
		var invalid := packet.duplicate(true)
		invalid.world.charges[0] = invalid_charge
		t.ok(not replica.accept(invalid, 4, "goal_guard"), "reject invalid charge")
	for invalid_generation in [-1, 0.5, 1000001, INF]:
		var invalid := packet.duplicate(true)
		invalid.world.balls[0].generation = invalid_generation
		t.ok(not replica.accept(invalid, 4, "goal_guard"), "reject invalid launch generation")
	var invalid := packet.duplicate(true)
	invalid.world.balls[0].position[0] = NAN
	t.ok(not replica.accept(invalid, 4, "goal_guard"), "reject non-finite ball position")
	invalid = packet.duplicate(true)
	for i in 4:
		invalid.world.balls.append(packet.world.balls[0].duplicate(true))
	t.ok(not replica.accept(invalid, 4, "goal_guard"), "bound replicated ball count")
	t.ok(not replica.accept(packet, 4, "unknown"), "unsupported games cannot silently use player-only snapshots")
	game.on_round_start()
	replica.render(scene, 1.0 / 60.0)
	t.equal(game.balls.size(), 2, "guest creates host-owned balls")
	t.ok(game.balls[1].heavy, "heavy ball appearance restored")
	t.near(game.charges[0], 0.25, 0.001, "host charge restored")
	t.equal(game.balls[0].global_position, Vector3(2, 0.9, 3), "first snapshot snaps ball to host")
	var before_scores: Array = Array(scene.ctx.scores)
	for i in 60:
		replica.render(scene, 1.0 / 60.0)
	t.equal(Array(scene.ctx.scores), before_scores, "presentation never scores or simulates goals")
	t.equal(game.balls[0].global_position, Vector3(2, 0.9, 3), "no independent guest ball simulation")
	for ball: GameBall in game.balls:
		t.ok(not ball.is_monitoring() and ball.collision_layer == 0 and ball.collision_mask == 0, "replica collision disabled")
	packet.world.balls[0].generation += 1
	packet.world.balls[0].position = [0, 0.9, 0]
	t.ok(replica.accept(packet, 4, "goal_guard"), "accept host relaunch")
	replica.render(scene, 0.001)
	t.equal(game.balls[0].global_position, Vector3(0, 0.9, 0), "goal relaunch teleports instead of sliding")
	packet.world.balls.resize(1)
	packet.round += 1
	packet.fighters[1].alive = false
	packet.fighters[1].visible = false
	t.ok(replica.accept(packet, 4, "goal_guard"), "accept next round")
	replica.render(scene, 0.001)
	t.equal(game.balls.size(), 1, "round reset removes excess replica balls")
	t.ok(not game.paddles[1].visible, "eliminated keeper shield hidden")
	game.ctx.config.rules["online_contenders"] = [0, 2]
	game.on_round_start()
	t.equal(Array(scene.ctx.scores), [12, 0, 12, 0], "spectators cannot win a keeper tiebreak or lose goal points")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
