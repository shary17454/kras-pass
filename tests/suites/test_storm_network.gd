extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("storm network")
	for count in [2, 3, 4]:
		var cfg := MatchConfig.build("storm_heart", ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 88)
		cfg.players.resize(count)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": cfg, "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		var game = scene.controller
		game._volley_timer = 0.01
		game.tick(0.02)
		t.equal(game._warning_sequence, 1, "host warning advances event sequence")
		t.ok(game.is_winding(), "host warning starts windup")
		for i in 8:
			game._fire_volley()
		t.equal(game.balls.size(), count + 2, "host caps volleys at roster plus two")
		for ball: GameBall in game.balls:
			game._tick_ball(ball, 0.35)
		t.equal(scene.ctx.definition.control_profile, ControlProfile.Kind.KEEPER, "turbine court uses keeper controls")
		var replica = load("res://src/net/match_replica.gd").new()
		var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
		t.ok(replica.accept(packet, count, "storm_heart"), "full turbine state survives JSON round trip")
		t.ok(not replica.accept(packet, count, "goal_guard"), "ordinary keeper court does not accept extra balls")
		for field in ["rotor", "windup", "volley_timer", "warning_sequence", "volley_sequence"]:
			var bad := packet.duplicate(true)
			bad.world.erase(field)
			t.ok(not replica.accept(bad, count, "storm_heart"), "reject missing " + field)
			for value in [true, "1", INF, -1]:
				bad.world[field] = value
				t.ok(not replica.accept(bad, count, "storm_heart"), "reject malformed " + field)
		var extra := packet.duplicate(true)
		extra.world.balls.append(extra.world.balls[0])
		t.ok(not replica.accept(extra, count, "storm_heart"), "reject excess ball count")
		t.equal(replica.target, packet, "invalid packets preserve accepted state")
		game.on_round_start()
		t.equal(game._volley_sequence, 8, "round reset preserves monotonic volley sequence")
		packet.world.rotor = 1.25
		packet.world.windup = 0.1
		packet.phase = MatchPhase.P.PLAYING
		packet.time = 45.0
		t.ok(replica.accept(packet, count, "storm_heart"), "accept imminent volley")
		AudioManager._last_played.erase("shoot")
		replica.render(scene, 0.5)
		t.ok(not AudioManager._last_played.has("shoot"), "first snapshot never replays old volley")
		t.equal(game.balls.size(), count + 2, "guest renders all additional balls")
		var scores: Array = Array(scene.ctx.scores)
		for i in 20:
			replica.render(scene, 0.5)
		t.near(game._windup, 0.1, 0.001, "guest never advances windup")
		t.near(game._blades.rotation.y, 1.25, 0.001, "guest turbine uses host rotation")
		t.equal(Array(scene.ctx.scores), scores, "guest never scores simulated goals")
		for ball: GameBall in game.balls:
			t.ok(not ball.is_monitoring() and ball.collision_layer == 0, "replica balls cannot collide")
		packet.world.volley_sequence += 1
		t.ok(replica.accept(packet, count, "storm_heart"), "accept fresh volley")
		replica.render(scene, 0.1)
		t.equal(replica._storm.volley_sequence, int(packet.world.volley_sequence), "fresh sequence consumed")
		if AudioManager.enabled:
			t.ok(AudioManager._last_played.has("shoot"), "fresh volley plays pooled sound")
		AudioManager._last_played.erase("shoot")
		replica.render(scene, 0.1)
		t.ok(not AudioManager._last_played.has("shoot"), "duplicate snapshot never repeats volley")
		packet.world.volley_sequence += 3
		t.ok(replica.accept(packet, count, "storm_heart"), "accept reconnect state")
		replica._event_received_at = replica.received_at - 1501
		replica.render(scene, 0.1)
		t.ok(not AudioManager._last_played.has("shoot"), "reconnect suppresses historical volley")
		packet.phase = MatchPhase.P.PAUSED
		packet.world.volley_sequence += 1
		t.ok(replica.accept(packet, count, "storm_heart"), "accept paused snapshot")
		replica.render(scene, 0.1)
		t.ok(not AudioManager._last_played.has("shoot"), "paused snapshot cannot play volley feedback")
		packet.phase = MatchPhase.P.PLAYING
		t.ok(replica.accept(packet, count, "storm_heart"), "accept resumed snapshot")
		replica.render(scene, 0.1)
		t.ok(not AudioManager._last_played.has("shoot"), "resume never replays muted volley")
		packet.world.warning_sequence += 1
		AudioManager._last_played.erase("countdown")
		t.ok(replica.accept(packet, count, "storm_heart"), "accept fresh warning")
		replica.render(scene, 0.1)
		if AudioManager.enabled:
			t.ok(AudioManager._last_played.has("countdown"), "fresh warning plays pooled sound")
		if count == 4 and DisplayServer.get_name() != "headless":
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--capture-storm="):
					await host.get_tree().create_timer(1.2).timeout
					await RenderingServer.frame_post_draw
					t.equal(host.get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture-storm=")), OK, "save turbine presentation")
		packet.round += 1
		packet.world.balls.resize(1)
		packet.world.windup = 0
		packet.world.volley_sequence += 1
		t.ok(replica.accept(packet, count, "storm_heart"), "accept next round")
		replica.render(scene, 0.1)
		t.equal(game.balls.size(), 1, "round reset removes extra balls")
		t.ok(not AudioManager._last_played.has("shoot"), "new round does not replay old volley")
		t.ok(not game.is_winding(), "host clears guest warning")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
