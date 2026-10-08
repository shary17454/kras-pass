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
	await _scrap_multi_contact(t, host)


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


func _scrap_multi_contact(t: TestHarness, host: Node) -> void:
	var reference: Array = []
	for swapped in [false, true]:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("scrap_karts", ["fanoos", "fanoos", "fanoos", "fanoos"], 0, 2, 9616)})
		scene.set_physics_process(false)
		var physical_slots := [0, 2, 1, 3] if swapped else [0, 1, 2, 3]
		var positions := [Vector3(0, 1.3, 0), Vector3(2, 1.3, 0), Vector3(0, 1.3, 2), Vector3(100, 1.3, 100)]
		for physical in 4:
			var fighter: Fighter = scene.ctx.fighter(physical_slots[physical])
			fighter.set_physics_process(false)
			fighter.global_position = positions[physical]
			fighter.facing = Vector3.FORWARD
			fighter.velocity = Vector3(12, 0, 12) if physical == 0 else Vector3.ZERO
			fighter._invuln = 0.0
			fighter._impulse = Vector3.ZERO
		scene.controller._resolve_rams()
		t.equal(scene.controller.ram_serial, 2, "both simultaneous live contacts resolve")
		for physical in 4:
			var slot: int = physical_slots[physical]
			var fighter: Fighter = scene.ctx.fighter(slot)
			t.ok(scene.ctx.is_alive(slot), "multi-contact fixture has no elimination ordering")
			if not swapped:
				reference.append({"health": scene.controller.health[slot], "impulse": fighter._impulse})
			else:
				t.near(scene.controller.health[slot], reference[physical].health, 0.0001,
					"same physical kart takes the same health damage after seat permutation")
				t.near(fighter._impulse.distance_to(reference[physical].impulse), 0.0, 0.0001,
					"same physical kart receives the same combined impulse after seat permutation")
		var victim: Fighter = scene.ctx.fighter(physical_slots[1])
		var first_impulse := victim._impulse
		t.ok(not victim.take_hit(0, Vector3.BACK, 1.0), "ordinary hits still honor hit immunity")
		t.near(victim._impulse.distance_to(first_impulse), 0.0, 0.0001, "blocked ordinary hit adds no impulse")
		t.ok(victim.take_ram_hit(0, Vector3.BACK, 1.0), "accepted ram feedback is not suppressed by hit immunity")
		t.ok(victim._impulse.distance_to(first_impulse) > 0.0, "accepted ram contributes its impulse")
		victim.teammates[0] = true
		t.ok(not victim.take_ram_hit(0, Vector3.BACK, 1.0), "ram entry point retains teammate protection")
		victim.teammates.clear()
		victim.alive = false
		t.ok(not victim.take_ram_hit(0, Vector3.BACK, 1.0), "ram entry point rejects eliminated bodies")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
