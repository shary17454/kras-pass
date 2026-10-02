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
	for field in ["drone", "rotor", "target", "mark", "cycle", "owners"]:
		var bad := packet.duplicate(true)
		bad.world.erase(field)
		t.ok(not replica.accept(bad, 4, "mukharrib"), "reject missing " + field)
	for field in ["rotor", "target", "mark", "cycle"]:
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
	game.on_round_start()
	t.equal(game._markers.size(), 0, "round restart clears warning")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
