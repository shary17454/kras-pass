extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("color network presentation")
	var cfg := MatchConfig.build("color_stand", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 105)
	var capture_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-color-network="):
			capture_path = arg.trim_prefix("--capture-color-network=")
	if not capture_path.is_empty():
		cfg.players[0].is_human = true
		cfg.players[0].device_type = 2
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	t.equal(scene.arena.tiles.size(), 121, "authored quilt count matches protocol")
	var replica = load("res://src/net/match_replica.gd").new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	packet.phase = MatchPhase.P.PLAYING
	packet.time = 30
	t.ok(replica.accept(packet, 4, "color_stand"), "host quilt survives JSON")
	for field in ["tiles", "colors", "called", "stage", "timer", "call_sequence", "drop_sequence"]:
		var bad := packet.duplicate(true)
		bad.world.erase(field)
		t.ok(not replica.accept(bad, 4, "color_stand"), "reject missing " + field)
	for field in ["called", "stage", "timer", "call_sequence", "drop_sequence"]:
		for value in [null, true, "1", NAN, INF, -1, 1000001]:
			var bad := packet.duplicate(true)
			bad.world[field] = value
			t.ok(not replica.accept(bad, 4, "color_stand"), "reject invalid " + field)
	for value in [null, true, "1", NAN, INF, -1, 4, 0.5]:
		var bad := packet.duplicate(true)
		bad.world.colors[0] = value
		t.ok(not replica.accept(bad, 4, "color_stand"), "reject invalid tile color")
	var bad := packet.duplicate(true)
	bad.world.tiles.pop_back()
	t.ok(not replica.accept(bad, 4, "color_stand"), "reject truncated floor")
	bad = packet.duplicate(true)
	bad.world.colors.pop_back()
	t.ok(not replica.accept(bad, 4, "color_stand"), "reject truncated palette")
	t.equal(replica.target, packet, "invalid snapshot preserves previous state")
	game._repaint()
	AudioManager._last_played.erase("countdown")
	replica.render(scene, 0.1)
	t.ok(not AudioManager._last_played.has("countdown"), "first snapshot suppresses old call")
	var scores := Array(scene.ctx.scores)
	for repeat in 10:
		replica.render(scene, 1.0)
	t.near(game._timer, packet.world.timer, 0.00001, "guest does not advance countdown")
	t.equal(Array(scene.ctx.scores), scores, "guest does not score")
	for i in 121:
		var tile: ArenaTile = scene.arena.tiles[i]
		t.equal(tile.tag, game.COLOR_NAMES[int(packet.world.colors[i])], "guest quilt matches host tags")
		t.equal(tile.base_color, game.COLORS[int(packet.world.colors[i])], "guest quilt matches host colors")
		t.equal(tile.collision_layer, 0, "guest has no floor authority")
	packet.world.called = 2
	packet.world.call_sequence += 1
	t.ok(replica.accept(packet, 4, "color_stand"), "accept new color call")
	replica.render(scene, 0.1)
	t.equal(game.called_tag(), "yellow", "guest receives host target")
	if AudioManager.enabled:
		t.ok(AudioManager._last_played.has("countdown"), "new call plays feedback")
	AudioManager._last_played.erase("countdown")
	replica.render(scene, 0.1)
	t.ok(not AudioManager._last_played.has("countdown"), "duplicate call stays silent")
	packet.world.stage = 1
	packet.world.timer = 1.6
	packet.world.drop_sequence += 1
	packet.world.tiles[0] = [2, 0.2, -1, 1]
	t.ok(replica.accept(packet, 4, "color_stand"), "accept host drop")
	AudioManager._last_played.erase("whistle")
	replica.render(scene, 0.1)
	t.equal(scene.arena.tiles[0].state, ArenaTile.State.FALLING, "guest presents dropped tile")
	t.near(scene.arena.tiles[0].position.y, -1, 0.00001, "guest presents host height")
	if AudioManager.enabled:
		t.ok(AudioManager._last_played.has("whistle"), "fresh drop plays feedback")
	AudioManager._last_played.erase("whistle")
	packet.world.drop_sequence += 1
	t.ok(replica.accept(packet, 4, "color_stand"), "accept reconnect snapshot")
	replica._event_received_at = replica.received_at - 1501
	replica.render(scene, 0.1)
	t.ok(not AudioManager._last_played.has("whistle"), "reconnect skips old drop")
	if not capture_path.is_empty() and DisplayServer.get_name() != "headless":
		for i in 121:
			packet.world.tiles[i] = [0, 0, 0, 0] if int(packet.world.colors[i]) == 2 else [3, 0, -12, 1]
		t.ok(replica.accept(packet, 4, "color_stand"), "accept collapsed quilt fixture")
		replica.render(scene, 1.0)
		for slot in 4:
			var tile: ArenaTile = game.safe_tile_near(scene.ctx.fighter(slot).global_position)
			t.ok(tile != null, "fixture player has a visible safe tile")
			var position := tile.global_position + Vector3(0, 0.9, 0)
			packet.fighters[slot].position = [position.x, position.y, position.z]
		t.ok(replica.accept(packet, 4, "color_stand"), "accept safe player positions")
		replica.render(scene, 1.0)
		scene.camera._intro_left = 0
		await host.get_tree().create_timer(1.2).timeout
		if scene._pause_menu != null or scene._paused:
			scene._toggle_pause()
		await host.get_tree().process_frame
		await RenderingServer.frame_post_draw
		t.equal(scene.touch_sources.size(), 1, "replica fixture has touch controls")
		t.ok(scene._pause_menu == null, "replica fixture is unobscured")
		t.equal(host.get_viewport().get_texture().get_image().save_png(capture_path), OK, "save replicated color floor")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
