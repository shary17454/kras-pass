extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("sky network")
	for count in [2, 3, 4]:
		var cfg := MatchConfig.build("sky_court", ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 94)
		cfg.players.resize(count)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": cfg, "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		var game = scene.controller
		var replica = load("res://src/net/match_replica.gd").new()
		game._cycle = 0.01
		game.tick(0.02)
		var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
		t.ok(replica.accept(packet, count, "sky_court"), "host warning survives JSON round trip")
		for field in ["engine", "bank", "warning", "tilting", "cycle", "warning_sequence", "tilt_sequence"]:
			var bad := packet.duplicate(true)
			bad.world.erase(field)
			t.ok(not replica.accept(bad, count, "sky_court"), "reject missing " + field)
			for value in [true, "1", INF, -2]:
				bad.world[field] = value
				t.ok(not replica.accept(bad, count, "sky_court"), "reject malformed " + field)
		for field in ["engine", "bank", "warning", "tilting", "cycle"]:
			var bad := packet.duplicate(true)
			bad.world[field] = 10
			t.ok(not replica.accept(bad, count, "sky_court"), "reject excessive " + field)
		t.equal(replica.target, packet, "invalid snapshots preserve accepted state")
		packet.phase = MatchPhase.P.PLAYING
		packet.time = 45.0
		packet.world.warning = 0.8
		packet.world.bank = 0.75
		packet.world.tilting = 2.0
		for index in 4:
			packet.world.engine = index
			t.ok(replica.accept(packet, count, "sky_court"), "accept every authored tilt direction")
			replica.render(scene, 0.1)
			var down: Vector3 = game.engine_direction(index)
			var eased := 0.75 * 0.75 * (3.0 - 2.0 * 0.75)
			var expected := Quaternion(Vector3(down.z, 0, -down.x), game.TILT_ANGLE * eased)
			t.ok(scene.arena.quaternion.is_equal_approx(expected), "guest bank matches host direction and amount")
			t.ok(game._surface_height(scene.arena.global_position + down * 5.0) < scene.arena.global_position.y,
				"every engine produces the same visible and physical downhill direction")
			for i in 4:
				t.ok(game._engines[i].scale.x < 1.0 if i == index else game._engines[i].scale == Vector3.ONE, "only selected engine pulses")
		var scores: Array = Array(scene.ctx.scores)
		var velocity: Vector3 = game.balls[0].velocity
		for i in 20:
			replica.render(scene, 0.5)
		t.near(game._bank, 0.75, 0.001, "guest never advances tilt")
		t.near(game._warn, 0.8, 0.001, "guest never advances warning")
		t.equal(game.balls[0].velocity, velocity, "guest never applies slope acceleration")
		t.equal(Array(scene.ctx.scores), scores, "guest never scores goals")
		AudioManager._last_played.erase("explode")
		packet.world.tilt_sequence += 1
		t.ok(replica.accept(packet, count, "sky_court"), "accept fresh tilt event")
		replica.render(scene, 0.1)
		if AudioManager.enabled:
			t.ok(AudioManager._last_played.has("explode"), "fresh tilt plays sound")
		AudioManager._last_played.erase("explode")
		replica.render(scene, 0.1)
		t.ok(not AudioManager._last_played.has("explode"), "duplicate snapshot never repeats tilt")
		packet.world.tilt_sequence += 2
		t.ok(replica.accept(packet, count, "sky_court"), "accept reconnect state")
		replica._event_received_at = replica.received_at - 1501
		replica.render(scene, 0.1)
		t.ok(not AudioManager._last_played.has("explode"), "reconnect never replays old tilt")
		if count == 4 and DisplayServer.get_name() != "headless":
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--capture-sky="):
					await host.get_tree().create_timer(1.2).timeout
					if scene._paused:
						scene._toggle_pause()
					await host.get_tree().process_frame
					await RenderingServer.frame_post_draw
					t.equal(host.get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture-sky=")), OK, "save tilted court")
		packet.round += 1
		packet.world.engine = -1
		packet.world.bank = 0
		packet.world.warning = 0
		packet.world.tilting = 0
		packet.world.tilt_sequence += 1
		t.ok(replica.accept(packet, count, "sky_court"), "accept level next round")
		replica.render(scene, 0.1)
		t.ok(scene.arena.quaternion.is_equal_approx(Quaternion.IDENTITY), "next round immediately levels guest arena")
		t.ok(not AudioManager._last_played.has("explode"), "round change suppresses old events")
		for engine: Node3D in game._engines:
			t.equal(engine.scale, Vector3.ONE, "next round clears warning pulse")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
