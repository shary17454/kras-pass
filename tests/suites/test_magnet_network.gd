extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("magnet network")
	await _physics(t, host)
	for count in [2, 3, 4]:
		var cfg := MatchConfig.build("magnet_court", ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 73)
		cfg.players.resize(count)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": cfg, "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		var game = scene.controller
		game._spawn_ball(true)
		game._activate(0)
		game.balls[0].global_position = scene.ctx.fighter(0).global_position + Vector3.UP * 0.9
		game._attract(0, 0.1)
		game._activate(count - 1)
		game.balls[1].global_position = scene.ctx.fighter(count - 1).global_position + Vector3.UP * 0.9
		game._attract(count - 1, 0.1)
		var old_id: int = game.balls[1].get_instance_id()
		var replica = load("res://src/net/match_replica.gd").new()
		var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
		t.ok(replica.accept(packet, count, "magnet_court"), "host magnet state survives JSON round trip")
		t.equal(packet.world.magnet_charge.size(), count, "meter count follows roster")
		t.equal(packet.world.magnet_active.size(), count, "active timers follow roster")
		t.equal(packet.world.held, [0.0, float(count - 1)], "ball slots replace host engine identities")
		for field in ["magnet_charge", "magnet_active", "held"]:
			var bad := packet.duplicate(true)
			bad.world.erase(field)
			t.ok(not replica.accept(bad, count, "magnet_court"), "reject absent " + field)
			bad.world[field] = []
			t.ok(not replica.accept(bad, count, "magnet_court"), "reject empty " + field)
		for field in ["magnet_charge", "magnet_active"]:
			for value in [-1, 1.2, INF, true, "1"]:
				var bad := packet.duplicate(true)
				bad.world[field][0] = value
				t.ok(not replica.accept(bad, count, "magnet_court"), "reject malformed meter")
		for value in [-2, count, 0.5, true, "0"]:
			var bad := packet.duplicate(true)
			bad.world.held[0] = value
			t.ok(not replica.accept(bad, count, "magnet_court"), "reject malformed ball owner")
		t.equal(replica.target, packet, "invalid packet preserves accepted state")
		game.on_round_start()
		replica.render(scene, 0.1)
		t.ok(game.balls[1].get_instance_id() != old_id, "reset replaces extra ball identity")
		t.ok(not game._held.has(old_id), "guest does not retain host engine identity")
		t.equal(game._held.get(game.balls[0].get_instance_id()), 0, "first ball maps to guest identity")
		t.equal(game._held.get(game.balls[1].get_instance_id()), count - 1, "second ball maps to its owner")
		t.ok(game.balls[1].heavy, "shared ball renderer retains heavy appearance")
		var scores: Array = Array(scene.ctx.scores)
		for i in 20:
			replica.render(scene, 0.1)
		t.near(game._charge[0], 0, 0.001, "guest never recharges magnet")
		t.near(game._magnet_until[0], 1.1, 0.001, "guest never expires active magnet")
		t.equal(Array(scene.ctx.scores), scores, "guest never simulates goals")
		t.equal(int(scene.ctx.details[0].get("volleys", 0)), 0, "guest never awards release statistics")
		t.ok(not game.magnet_ready(0), "HUD readiness reflects active host magnet")
		for ball: GameBall in game.balls:
			t.ok(not ball.is_monitoring() and ball.collision_layer == 0, "guest balls cannot collide")
		if count == 4 and DisplayServer.get_name() != "headless":
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--capture-magnet="):
					await host.get_tree().process_frame
					await RenderingServer.frame_post_draw
					t.equal(host.get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture-magnet=")), OK, "save held-ball presentation")
		packet.world.held = [-1, -1]
		packet.world.magnet_active.fill(0)
		packet.world.magnet_charge.fill(1)
		packet.world.balls[0].generation += 1
		packet.world.balls[0].position = [4, 0.9, -2]
		t.ok(replica.accept(packet, count, "magnet_court"), "accept host release")
		replica.render(scene, 0.001)
		t.ok(game._held.is_empty(), "release clears all guest ownership")
		t.ok(game.magnet_ready(0), "host-ready charge reaches HUD")
		t.equal(game.balls[0].global_position, Vector3(4, 0.9, -2), "release generation snaps without false interpolation")
		packet.world.balls.resize(1)
		packet.world.held.resize(1)
		packet.round += 1
		t.ok(replica.accept(packet, count, "magnet_court"), "accept next-round ball count")
		replica.render(scene, 0.1)
		t.equal(game.balls.size(), 1, "round transition removes excess balls")
		t.ok(game._held.is_empty(), "removed balls leave no ownership entries")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame


func _physics(t: TestHarness, host: Node) -> void:
	var cfg := MatchConfig.build("magnet_court", ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 74)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	t.equal(scene.ctx.definition.control_profile, ControlProfile.Kind.KEEPER, "magnet uses single-stick keeper controls")
	var touch := TouchSource.new()
	host.add_child(touch)
	touch.setup(0, scene.ctx.definition)
	t.ok(not ControlProfile.shows_aim_stick(touch.profile), "magnet has no unused aiming stick")
	t.equal(touch.buttons, ["dash", "ability"], "magnet and dash controls remain available")
	for view in [Vector2(720, 1560), Vector2(1920, 1080)]:
		touch.size = view
		for i in touch.buttons.size():
			var position := touch._button_centre(i)
			t.ok(Rect2(Vector2.ZERO, view).has_point(position), "magnet button stays inside viewport")
			t.ok(position.distance_to(touch._stick_centre()) > 184.0, "magnet controls do not overlap steering")
			t.equal(touch._button_hit(position), i, "magnet button hit area matches position")
	touch.queue_free()
	for fps in [30, 60, 120]:
		game.on_round_start()
		var fighter: Fighter = scene.ctx.fighter(0)
		var ball: GameBall = game.balls[0]
		var normal: Vector3 = game.NORMALS[game.side_for(0)]
		var delta: float = 1.0 / fps
		ball.launch(fighter.global_position + normal * (game.CATCH_RADIUS + 26.0 * delta * 0.5), -normal, 26.0)
		game._activate(0)
		game._tick_ball(ball, delta)
		t.equal(game._held.get(ball.get_instance_id()), 0, "swept capture intercepts fast ball before shield")
		t.equal(ball.velocity, Vector3.ZERO, "held ball has no autonomous velocity")
		var generation := ball.launch_generation
		var score: int = scene.ctx.scores[0]
		for i in 15:
			game.tick(1.0 / 30.0)
		t.equal(game._held.get(ball.get_instance_id()), 0, "normal ticks retain captured ball")
		t.near(ball.speed, 0, 0.001, "normal ticks never restore held ball speed")
		t.equal(scene.ctx.scores[0], score, "held ball cannot concede a goal")
		t.equal(ball.launch_generation, generation, "holding never relaunches ball")
		game._magnet_until[0] = 0.01
		game.tick(0.02)
		t.ok(game._held.is_empty(), "expiry releases captured ball")
		t.ok(ball.launch_generation > generation, "release advances replicated launch generation")
		t.near(ball.speed, game.RELEASE_SPEED, 0.001, "release restores designed shot speed")
		t.ok(ball.velocity.dot(normal) > 0, "release travels away from keeper's goal")
		t.equal(ball.last_toucher, 0, "release keeps correct scoring credit")
		game._activate(0)
		ball.global_position = fighter.global_position + normal
		game._attract(0, 0.1)
		scene.ctx.eliminate(0)
		game.tick(0.02)
		t.ok(game._held.is_empty(), "eliminated keeper cannot retain or recapture a ball")
		t.near(game._magnet_until[0], 0, 0.001, "elimination clears active magnet")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
