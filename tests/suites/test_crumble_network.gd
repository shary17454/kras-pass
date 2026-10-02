extends RefCounted

class FixtureTransport extends Node:
	func send(_message: Dictionary) -> bool:
		return true


func run(t: TestHarness, host: Node) -> void:
	t.suite("crumble network")
	var saved_transport: Node = Net.transport
	var saved_match: Dictionary = Net.match_data
	var transport := FixtureTransport.new()
	host.add_child(transport)
	Net.transport = transport
	Net.match_data = {"fixture": true}
	for count in [2, 3, 4]:
		var cfg := MatchConfig.build("crumble_court", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 103)
		cfg.context = MatchConfig.Context.ONLINE
		cfg.allow_powerups = false
		cfg.players.resize(count)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": cfg, "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		t.ok(scene.machine == null and scene.ctx.machine == null, "online scene cannot create unreplicated machine")
		var tiles: Array = scene.arena.tiles
		t.equal(tiles.size(), 113, "authored layout matches protocol tile count")
		var index := 0
		for x in range(-6, 7):
			for z in range(-6, 7):
				if x * x + z * z > 36:
					continue
				t.equal(Vector2i(tiles[index].grid_x, tiles[index].grid_z), Vector2i(x, z), "canonical tile identity")
				index += 1
		tiles[0].touch()
		tiles[0].tick(0.2)
		tiles[1].force_collapse()
		tiles[1].tick(0.5)
		tiles[2].force_collapse()
		tiles[2].tick(2.0)
		var replica = load("res://src/net/match_replica.gd").new()
		var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
		t.ok(replica.accept(packet, count, "crumble_court"), "all tile phases survive JSON")
		for value in [null, {}, [], "tiles"]:
			var bad := packet.duplicate(true)
			bad.world = value
			t.ok(not replica.accept(bad, count, "crumble_court"), "reject missing tile state")
		for column in 4:
			for value in [true, "1", INF, NAN, -100, 1000001]:
				var bad := packet.duplicate(true)
				bad.world.tiles[0][column] = value
				t.ok(not replica.accept(bad, count, "crumble_court"), "reject malformed tile field")
		for row in [[0, 1, 0, 0], [0, 0, -1, 0], [1, 1, 0, 0], [1, 0.5, -1, 0], [1.5, 0, 0, 0], [2, 0, -1, 0.5]]:
			var bad := packet.duplicate(true)
			bad.world.tiles[0] = row
			t.ok(not replica.accept(bad, count, "crumble_court"), "reject inconsistent phase and fractional identifiers")
		t.equal(replica.target, packet, "rejected packet preserves last good state")
		packet.phase = MatchPhase.P.PLAYING
		packet.time = 30
		scene.controller.on_round_start()
		t.ok(replica.accept(packet, count, "crumble_court"), "accept snapshot after local reset")
		AudioManager._last_played.erase("crate_break")
		replica.render(scene, 0.1)
		t.ok(not AudioManager._last_played.has("crate_break"), "first snapshot suppresses historical collapse sound")
		var score: Array = Array(scene.ctx.scores)
		for repeat in 10:
			replica.render(scene, 1.0)
		for i in tiles.size():
			t.equal(tiles[i].state, int(packet.world.tiles[i][0]), "guest phase agrees with host")
			t.near(tiles[i]._timer, float(packet.world.tiles[i][1]), 0.00001, "guest never advances floor timers")
			t.near(tiles[i].position.y, float(packet.world.tiles[i][2]), 0.00001, "guest presents host floor height")
			t.equal(tiles[i].collision_layer, 0, "guest floor has no authority collisions")
			t.equal(tiles[i].visible, tiles[i].state != ArenaTile.State.GONE, "gone floor hidden on guest")
		t.equal(Array(scene.ctx.scores), score, "floor presentation cannot score or eliminate")
		packet.world.tiles[0] = [2, 0.1, -0.3, 1]
		t.ok(replica.accept(packet, count, "crumble_court"), "accept new collapse")
		replica.render(scene, 0.1)
		if AudioManager.enabled:
			t.ok(AudioManager._last_played.has("crate_break"), "fresh collapse plays pooled sound")
		AudioManager._last_played.erase("crate_break")
		replica.render(scene, 0.1)
		t.ok(not AudioManager._last_played.has("crate_break"), "repeated snapshot cannot replay collapse sound")
		packet.world.tiles[0][3] = 3
		t.ok(replica.accept(packet, count, "crumble_court"), "accept reconnect floor state")
		replica._event_received_at = replica.received_at - 1501
		replica.render(scene, 0.1)
		t.ok(not AudioManager._last_played.has("crate_break"), "reconnect skips old collapse events")
		if count == 4 and DisplayServer.get_name() != "headless":
			for arg in OS.get_cmdline_user_args():
				if arg.begins_with("--capture-crumble="):
					for i in packet.world.tiles.size():
						if i % 11 == 0:
							packet.world.tiles[i] = [3, 1, -12, 1]
						elif i % 7 == 0:
							packet.world.tiles[i] = [2, 0.3, -2, 1]
						elif i % 5 == 0:
							packet.world.tiles[i] = [1, 0.2, 0, 0]
					t.ok(replica.accept(packet, count, "crumble_court"), "accept mixed-floor visual fixture")
					replica.render(scene, 0.1)
					scene.camera._intro_left = 0
					await host.get_tree().create_timer(1.2).timeout
					if scene._pause_menu != null or scene._paused:
						scene._toggle_pause()
					await host.get_tree().process_frame
					t.ok(scene._pause_menu == null, "capture is not obscured by online pause menu")
					await RenderingServer.frame_post_draw
					t.equal(host.get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture-crumble=")), OK, "save replicated floor fixture")
		packet.round += 1
		for row in packet.world.tiles:
			row[0] = 0
			row[1] = 0
			row[2] = 0
		t.ok(replica.accept(packet, count, "crumble_court"), "accept next round floor reset")
		replica.render(scene, 0.1)
		for tile: ArenaTile in tiles:
			t.ok(tile.visible and tile.state == ArenaTile.State.SOLID and tile.position.y == 0, "new round restores guest floor")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
	Net.transport = saved_transport
	Net.match_data = saved_match
	transport.queue_free()
	await host.get_tree().process_frame
