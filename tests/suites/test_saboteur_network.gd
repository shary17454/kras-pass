extends RefCounted

const Paint = preload("res://src/net/paint_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("saboteur network")
	var cfg := MatchConfig.build("mukharrib", ["fanoos", "nabta", "ramla", "sakhra"], 0, 1, 86)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	var replica = load("res://src/net/match_replica.gd").new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	t.ok(replica.accept(packet, 4, "mukharrib"), "idle drone survives JSON round trip")
	game._choose_target()
	packet = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	t.ok(replica.accept(packet, 4, "mukharrib"), "host warning survives JSON round trip")
	t.equal(packet.world.target, float(Paint._index(game._target)), "capture uses authored target coordinates")
	for field in ["drone", "rotor", "target", "mark", "cycle", "owners", "warning_sequence", "scrub_sequence", "scrub_position"]:
		var bad := packet.duplicate(true)
		bad.world.erase(field)
		t.ok(not replica.accept(bad, 4, "mukharrib"), "reject missing " + field)
	for field in ["rotor", "target", "mark", "cycle", "warning_sequence", "scrub_sequence"]:
		for value in [true, "1", INF, -2]:
			var bad := packet.duplicate(true)
			bad.world[field] = value
			t.ok(not replica.accept(bad, 4, "mukharrib"), "reject malformed " + field)
	t.equal(replica.target, packet, "invalid warning preserves prior state")
	game._clear_markers()
	game._target = null
	packet.world.target = 84
	packet.world.drone = [2, 3.2, -4]
	packet.world.rotor = 1.25
	packet.world.mark = 0.1
	packet.world.owners.fill(1)
	packet.scores[1] = 169
	t.ok(replica.accept(packet, 4, "mukharrib"), "accept warning near scrub time")
	replica.render(scene, 0.5)
	t.equal(Paint._index(game._target), 84, "guest warning selects correct tile")
	t.equal(game._markers.size(), 9, "centre warning marks nine tiles")
	t.ok(game._drone.global_position.is_equal_approx(Vector3(2, 3.2, -4)), "guest drone follows host")
	t.near(game._rotor.rotation.y, 1.25, 0.001, "guest rotor follows host")
	var marker: Node = game._markers[0]
	for i in 5:
		replica.render(scene, 0.5)
	t.equal(game._markers[0], marker, "unchanged warning reuses markers")
	t.near(game._mark, 0.1, 0.001, "guest never advances warning timer")
	t.equal(scene.ctx.scores[1], 169, "guest never scrubs or recounts points")
	for tile: ArenaTile in game._tiles:
		t.equal(tile.owner_slot, 1, "guest never scrubs claimed tiles")
	if DisplayServer.get_name() != "headless":
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--capture-saboteur="):
				await host.get_tree().process_frame
				await RenderingServer.frame_post_draw
				t.equal(host.get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture-saboteur=")), OK, "save drone warning evidence")
	packet.world.target = 0
	t.ok(replica.accept(packet, 4, "mukharrib"), "accept edge warning")
	replica.render(scene, 0.1)
	t.equal(game._markers.size(), 4, "corner warning stays on authored board")
	packet.world.target = -1
	packet.world.mark = 0
	packet.world.owners.fill(-1)
	packet.scores[1] = 0
	t.ok(replica.accept(packet, 4, "mukharrib"), "accept host scrub result")
	replica.render(scene, 0.1)
	t.equal(game._markers.size(), 0, "host scrub clears warning visuals")
	t.equal(game._target, null, "host scrub clears target")
	t.equal(scene.ctx.scores[1], 0, "host score reaches guest")
	packet.phase = MatchPhase.P.PLAYING
	packet.world.scrub_sequence += 1
	packet.world.scrub_position = [3, 0, 2]
	var bursts := _burst_count(scene.ctx.world_root)
	AudioManager._last_played.erase("explode")
	t.ok(replica.accept(packet, 4, "mukharrib"), "accept fresh scrub event")
	replica.render(scene, 0.1)
	t.equal(_burst_count(scene.ctx.world_root), bursts + 1, "fresh event creates one visual burst")
	if AudioManager.enabled:
		t.ok(AudioManager._last_played.has("explode"), "fresh scrub triggers its pooled sound")
	for i in 5:
		replica.render(scene, 0.1)
	t.equal(_burst_count(scene.ctx.world_root), bursts + 1, "repeated snapshot never repeats scrub effect")
	t.equal(scene.ctx.fighters[0].health, packet.fighters[0].health, "effect never applies guest damage")
	packet.world.scrub_sequence += 4
	t.ok(replica.accept(packet, 4, "mukharrib"), "accept state after disconnect")
	replica._event_received_at = replica.received_at - 1501
	replica.render(scene, 0.1)
	replica.render(scene, 0.1)
	t.equal(_burst_count(scene.ctx.world_root), bursts + 1, "reconnect does not replay old effects")
	packet.round += 1
	packet.world.scrub_sequence += 1
	t.ok(replica.accept(packet, 4, "mukharrib"), "accept next-round snapshot")
	replica.render(scene, 0.1)
	t.equal(_burst_count(scene.ctx.world_root), bursts + 1, "round transition does not replay effects")
	var new_replica = load("res://src/net/match_replica.gd").new()
	t.ok(new_replica.accept(packet, 4, "mukharrib"), "new guest accepts historical state")
	new_replica.render(scene, 0.1)
	t.equal(_burst_count(scene.ctx.world_root), bursts + 1, "first snapshot never plays old effects")
	packet.world.target = 84
	packet.world.mark = 1.5
	packet.world.warning_sequence += 1
	AudioManager._last_played.erase("countdown")
	t.ok(replica.accept(packet, 4, "mukharrib"), "accept fresh warning event")
	replica.render(scene, 0.1)
	if AudioManager.enabled:
		t.ok(AudioManager._last_played.has("countdown"), "new warning triggers countdown sound")
		var played_at: float = AudioManager._last_played.get("countdown", -1.0)
		replica.render(scene, 0.1)
		t.equal(AudioManager._last_played.get("countdown", -2.0), played_at, "duplicate warning never retriggers sound")
	game.on_round_start()
	t.equal(game._markers.size(), 0, "round restart clears warning")
	var previous_sequence: int = game._scrub_sequence
	game._choose_target()
	var scrub_position: Vector3 = game._target.global_position
	game._scrub()
	var host_world: Dictionary = replica.capture(scene).world
	t.equal(host_world.scrub_sequence, previous_sequence + 1, "actual host scrub advances event sequence")
	t.equal(host_world.scrub_position, [scrub_position.x, scrub_position.y, scrub_position.z], "host captures actual scrub position")
	game.on_round_start()
	t.equal(game._scrub_sequence, previous_sequence + 1, "event sequence stays monotonic across rounds")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame


func _burst_count(root: Node) -> int:
	var count := 0
	for child in root.get_children():
		var script: Script = child.get_script()
		if script != null and script.resource_path == "res://src/fx/burst.gd":
			count += 1
	return count
