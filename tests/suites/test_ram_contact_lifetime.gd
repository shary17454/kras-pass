extends RefCounted

func run(t: TestHarness, host: Node) -> void:
	t.suite("body contacts expire after their physics tick")
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": MatchConfig.build("ring_rumble", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 9614), "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var a: Fighter = scene.ctx.fighter(0)
	var b: Fighter = scene.ctx.fighter(1)
	t.ok(not a.teammates.has(b.slot) and not b.teammates.has(a.slot), "contact lifetime fixture uses rivals, not protected cooperative allies")
	Fighter.clear_impact_state()
	a._pre_vel = Vector3(10, 0, 0)
	b._pre_vel = Vector3.ZERO
	a._invuln = 0.0
	b._invuln = 0.0
	Fighter._contacts["0:1"] = {"a": a, "b": b, "into": Vector3.RIGHT}
	Fighter.resolve_impacts(1.0 / 60.0)
	t.ok(b._impulse.length() > 0.0, "fresh contact still delivers an impact")
	var first: Vector3 = b._impulse
	b.global_position = Vector3(100, 2, 0)
	a._invuln = 0.0
	b._invuln = 0.0
	Fighter.resolve_impacts(1.0)
	t.near(b._impulse.distance_to(first), 0.0, 0.001, "old separated pair cannot deliver another impact")
	t.ok(Fighter._contacts.is_empty(), "per-tick contact queue is drained")
	Fighter.clear_impact_state()
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	await _scrap_wreck(t, host)


func _scrap_wreck(t: TestHarness, host: Node) -> void:
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": MatchConfig.build("scrap_karts", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 9615)})
	scene.set_physics_process(false)
	for fighter in scene.ctx.fighters:
		fighter.set_physics_process(false)
	var game = scene.controller
	var a: Fighter = scene.ctx.fighter(0)
	var b: Fighter = scene.ctx.fighter(1)
	var c: Fighter = scene.ctx.fighter(2)
	a.global_position = Vector3(0, 1.3, 0)
	b.global_position = Vector3(2, 1.3, 0)
	c.global_position = Vector3(0, 1.3, 2)
	scene.ctx.fighter(3).global_position = Vector3(100, 1.3, 100)
	a.velocity = Vector3(12, 0, 12)
	b.velocity = Vector3.ZERO
	c.velocity = Vector3.FORWARD * 12.0
	game.health[0] = 1.0
	var third_health: float = game.health[2]
	game._resolve_rams()
	t.ok(not scene.ctx.is_alive(0), "backwash eliminates fragile attacker in the first pair")
	t.ok(game.health[1] < game._max_health, "the first live collision still damages its victim")
	t.equal(game.health[2], third_health, "wrecked attacker cannot damage another kart later in the same tick")
	t.ok(not game._hit_cooldown.has("0_2"), "wreck cannot create a new collision cooldown")
	t.equal(game.ram_serial, 1, "only the live collision produces ram feedback")
	game.on_round_start()
	scene.ctx.revive(0)
	a.alive = true
	a.velocity = Vector3(12, 0, 12)
	game._resolve_rams()
	t.ok(scene.ctx.is_alive(0), "healthy kart survives both ordinary contacts")
	t.ok(game.health[1] < game._max_health and game.health[2] < game._max_health,
		"live kart can still participate in two contacts during one tick")
	t.equal(game.ram_serial, 2, "healthy multi-contact retains both impact events")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
