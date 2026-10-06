extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("tag network")
	var cfg := MatchConfig.build("tag_hunt", ["fanoos", "nabta", "ramla", "sakhra"], 0, 1, 86)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	game.on_round_start()
	game._set_hunter(0)
	var replica = load("res://src/net/match_replica.gd").new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	t.ok(replica.accept(packet, 4, "tag_hunt"), "capture survives JSON round trip")
	for hunter in [-2, 4, 0.5, true, "1", INF]:
		var bad := packet.duplicate(true)
		bad.world.hunter = hunter
		t.ok(not replica.accept(bad, 4, "tag_hunt"), "reject invalid role")
	for grace in [-1, 2, true, "1", INF]:
		var bad := packet.duplicate(true)
		bad.world.grace = grace
		t.ok(not replica.accept(bad, 4, "tag_hunt"), "reject invalid grace")
	var bad := packet.duplicate(true)
	bad.erase("world")
	t.ok(not replica.accept(bad, 4, "tag_hunt"), "reject absent world")
	t.equal(replica.target, packet, "invalid updates preserve valid state")
	packet.world.hunter = 1
	packet.world.grace = 0.8
	t.ok(replica.accept(packet, 4, "tag_hunt"), "accept role handover")
	var accum: Array = game._free_accum.duplicate()
	for i in 20:
		replica.render(scene, 0.1)
	t.equal(game.hunter(), 1, "guest HUD follows hunter")
	t.near(game.handover_grace(), 0.8, 0.001, "guest grace follows host rather than local timer")
	t.near(scene.ctx.fighters[0].top_speed, game._base_speed[0], 0.001, "previous role speed restored")
	t.near(scene.ctx.fighters[1].top_speed, game._base_speed[1] * game.HUNTER_SPEED, 0.001, "role bonus not compounded by repeated snapshots")
	t.equal(game._free_accum, accum, "guest does not advance free-time scoring")
	t.equal(scene.ctx.scores[0] + scene.ctx.scores[1], 0, "guest does not award tags or survival points")
	if DisplayServer.get_name() != "headless":
		t.ok(is_instance_valid(game._mark), "graphical guest shows hunter marker")
		var mark: Node3D = game._mark
		replica.render(scene, 0.1)
		t.equal(game._mark, mark, "unchanged role reuses marker")
		t.ok(mark.global_position.is_equal_approx(scene.ctx.fighters[1].global_position + Vector3(0, 2.35, 0)), "marker follows hunter")
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--capture-tag="):
				await host.get_tree().process_frame
				await RenderingServer.frame_post_draw
				t.equal(host.get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture-tag=")), OK, "save hunter evidence")
	packet.world.hunter = -1
	packet.world.grace = 0
	t.ok(replica.accept(packet, 4, "tag_hunt"), "accept cleared role")
	replica.render(scene, 0.1)
	t.equal(game.hunter(), -1, "cleared role reaches guest")
	t.near(scene.ctx.fighters[1].top_speed, game._base_speed[1], 0.001, "clearing role restores speed")
	t.ok(game._mark == null, "clearing role removes marker")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
	await _test_contact_selection(t, host)


func _test_contact_selection(t: TestHarness, host: Node) -> void:
	var cfg := MatchConfig.build("tag_hunt", ["fanoos", "nabta", "ramla", "sakhra"], 0, 1, 86)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	for closest in [3, 2, 1]:
		game.on_round_start()
		game._set_hunter(0)
		game._grace = 0.0
		scene.ctx.scores.fill(0)
		scene.ctx.fighter(0).global_position = Vector3(0, 1, 0)
		for slot in [1, 2, 3]:
			scene.ctx.fighter(slot).global_position = Vector3(1.5, 1, 0)
		scene.ctx.fighter(closest).global_position = Vector3(0.8, 1, 0)
		game.tick(0.01)
		t.equal(game.hunter(), closest, "simultaneous contact chooses closest runner independent of slot order")
		t.equal(scene.ctx.scores[0], game.TAG_POINTS, "one contact awards one tag")
		t.equal(scene.ctx.scores[1] + scene.ctx.scores[2] + scene.ctx.scores[3], 0, "new hunter cannot tag again in same tick")
		t.near(game.handover_grace(), game.HANDOVER_GRACE, 0.001, "closest contact keeps handover grace")
		game.tick(0.01)
		t.equal(game.hunter(), closest, "grace prevents immediate contact bounce back")
	var tied_selections := {}
	for seed_value in range(64):
		var first_choice := -1
		for repeat in 2:
			game._set_hunter(0)
			game._grace = 0.0
			scene.ctx.rng.seed = seed_value
			scene.ctx.fighter(0).global_position = Vector3(0, 1, 0)
			scene.ctx.fighter(1).global_position = Vector3(1, 1, 0)
			scene.ctx.fighter(2).global_position = Vector3(-1, 1, 0)
			scene.ctx.fighter(3).global_position = Vector3(0, 1, 4)
			game.tick(0.01)
			t.ok(game.hunter() in [1, 2], "only equally closest touching runners enter selection")
			if repeat == 0:
				first_choice = game.hunter()
				tied_selections[first_choice] = true
			else:
				t.equal(game.hunter(), first_choice, "equal contact selection reproduces with same seed")
	t.equal(tied_selections.size(), 2, "equal contacts do not always favor first slot across fixed seeds")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
