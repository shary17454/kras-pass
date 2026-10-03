extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("relic hold")
	var cfg := MatchConfig.build("relic_hold", ["fanoos", "nabta", "ramla", "sakhra"], 0, 1, 86)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	var fighter: Fighter = scene.ctx.fighters[0]
	game.on_round_start()
	t.equal(game.loose_relic(), game._relic, "loose cue returns the actual spawned collectible")
	t.ok(fighter.can_attack, "initial player can attack")
	game._on_taken(game._relic, 0)
	t.equal(game.loose_relic(), null, "carrying removes the loose target cue")
	t.equal(game.holder(), 0, "pickup sets holder")
	t.equal(fighter.carrying, 1, "holder carries relic")
	t.ok(not fighter.can_attack, "holder cannot attack")
	game._accum = 0.7
	game.on_round_start()
	t.equal(game.holder(), -1, "round reset releases holder")
	t.equal(fighter.carrying, 0, "round reset clears carrying")
	t.ok(fighter.can_attack, "round reset restores attack permission")
	t.near(game._accum, 0.0, 0.001, "fractional score does not leak between rounds")
	t.ok(is_instance_valid(game._relic) and game._relic.available, "new round offers a collectible")
	var item: Collectible = game._relic
	game.on_round_start()
	t.equal(game._relic, item, "repeated round callback does not duplicate relic")
	game._on_taken(game._relic, 0)
	game.cleanup()
	game.cleanup()
	t.equal(game.holder(), -1, "cleanup releases ownership")
	t.equal(fighter.carrying, 0, "cleanup clears carrying")
	t.ok(fighter.can_attack, "cleanup restores attack permission")
	t.ok(game._relic == null and game._mark == null, "cleanup releases presentation")
	game.on_round_start()
	var replica = load("res://src/net/match_replica.gd").new()
	var loose: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	t.equal(loose.world.items.size(), 1, "host captures the loose relic")
	t.ok(replica.accept(loose, 4, "relic_hold"), "loose world accepts JSON round trip")
	game._on_taken(game._relic, 1)
	scene.ctx.set_score(1, 7)
	var carried: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	t.equal(carried.world.items.size(), 0, "carried relic is not also loose")
	t.equal(carried.world.holder, 1.0, "capture preserves carrier")
	for holder in [-2, 4, 0.5, "1", true, INF]:
		var bad := carried.duplicate(true)
		bad.world.holder = holder
		t.ok(not replica.accept(bad, 4, "relic_hold"), "reject invalid carrier")
	var bad := carried.duplicate(true)
	bad.world.items = loose.world.items
	t.ok(not replica.accept(bad, 4, "relic_hold"), "reject simultaneous loose and carried relic")
	bad = loose.duplicate(true)
	bad.world.items.append(loose.world.items[0].duplicate(true))
	bad.world.items[1].id = "999"
	t.ok(not replica.accept(bad, 4, "relic_hold"), "reject multiple relics")
	t.equal(replica.target, loose, "invalid state preserves previous world")
	t.ok(replica.accept(carried, 4, "relic_hold"), "accept carried state")
	replica.render(scene, 0.1)
	t.ok(game._relic == null, "guest releases authoritative collectible")
	t.equal(game.holder(), 1, "guest HUD identifies carrier")
	t.equal(scene.ctx.fighters[1].carrying, 1, "guest carrying follows authority")
	t.ok(not scene.ctx.fighters[1].can_attack, "guest carrier presentation disables attack")
	t.equal(replica._relic.items.views.size(), 0, "carried state removes loose visual")
	if DisplayServer.get_name() != "headless":
		t.ok(is_instance_valid(game._mark), "graphical guest shows carrier marker")
		var mark: Node3D = game._mark
		replica.render(scene, 0.1)
		t.equal(game._mark, mark, "unchanged carrier reuses marker")
		t.ok(mark.global_position.is_equal_approx(scene.ctx.fighters[1].global_position + Vector3(0, 2.3, 0)), "marker tracks carrier")
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--capture-relic="):
				await host.get_tree().process_frame
				await RenderingServer.frame_post_draw
				t.equal(host.get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture-relic=")), OK, "save graphical carrier evidence")
	var accum: float = game._accum
	for i in 10:
		replica.render(scene, 0.1)
	t.near(game._accum, accum, 0.001, "guest never advances held-time scoring")
	t.equal(scene.ctx.scores[1], 7, "guest never awards points")
	loose.scores = carried.scores.duplicate()
	t.ok(replica.accept(loose, 4, "relic_hold"), "accept dropped state")
	replica.render(scene, 0.1)
	t.equal(game.holder(), -1, "drop clears holder")
	t.equal(scene.ctx.fighters[1].carrying, 0, "drop clears carrying")
	t.ok(scene.ctx.fighters[1].can_attack, "drop restores attack presentation")
	t.equal(replica._relic.items.views.size(), 1, "drop restores loose visual")
	t.equal(replica._relic.find_children("*", "CollisionObject3D", true, false).size(), 0, "guest replica has no pickup colliders")
	var view = replica._relic.items.views.values()[0]
	replica.render(scene, 0.1)
	t.equal(replica._relic.items.views.values()[0], view, "repeated snapshots reuse visual")
	loose.world.items = []
	t.ok(replica.accept(loose, 4, "relic_hold"), "accept respawn delay without loose relic")
	replica.render(scene, 0.1)
	t.equal(replica._relic.items.views.size(), 0, "respawn delay removes loose visual")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
