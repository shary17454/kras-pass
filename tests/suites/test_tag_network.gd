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
