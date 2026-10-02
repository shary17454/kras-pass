extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("turret rounds and protected projectile hits")
	var cfg := MatchConfig.build("turret_duel", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 117)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	for fighter in scene.ctx.fighters:
		fighter.set_physics_process(false)
		fighter.global_position = Vector3(100 + fighter.slot * 10, 1, 100)
	game.on_round_start()
	for round_index in 3:
		game._fire(0)
		var shot: Projectile = game._shots.back()
		t.ok(shot.active, "old round has a live projectile")
		t.ok(game._cooldowns[0] > 0.0, "old round has launch cooldown")
		game.on_round_start()
		t.ok(game._shots.is_empty(), "new round releases old projectiles")
		t.ok(not shot.active and not shot.visible, "old shot cannot hit after countdown")
		for cooldown in game._cooldowns:
			t.equal(cooldown, 0.0, "new round restores immediate firing")
		t.equal(Pool.stats()[game.POOL_KEY].live, 0, "new round returns projectiles to pool")
	game.cleanup()
	for protection in ["invulnerable", "shield", "teammate", "none", "notify_only"]:
		var victim: Fighter = scene.ctx.fighter(1)
		victim.reset_damage()
		victim.alive = true
		victim._invuln = 1.0 if protection == "invulnerable" else 0.0
		victim.mods["shield"] = 1.0 if protection == "shield" else 0.0
		victim.teammates.clear()
		if protection == "teammate":
			victim.teammates[0] = true
		var shot := Projectile.new()
		scene.add_child(shot)
		shot.fire(victim.global_position, Vector3.FORWARD, 0, 24.0, 14.0, 26.0)
		shot.notify_only = protection == "notify_only"
		var hits := [0]
		shot.hit_fighter.connect(func(_shot, shooter, slot):
			hits[0] += 1
			t.equal(shooter, 0, "hit identifies shooter")
			t.equal(slot, 1, "hit identifies actual victim")
			game._on_hit(_shot, shooter, slot))
		for frame in 3:
			await host.get_tree().physics_frame
		t.ok(shot.get_overlapping_bodies().has(victim), "fixture uses real physics overlap")
		var before: int = scene.ctx.scores[0]
		shot.tick(0.0)
		var accepted: bool = protection in ["none", "notify_only"]
		t.equal(hits[0], 1 if accepted else 0, "only accepted or delegated hit emits score event")
		t.equal(scene.ctx.scores[0], before + (1 if accepted else 0), "blocked projectile cannot award hit points")
		t.equal(victim.damage_percent, 14.0 if protection == "none" else 0.0, "protected/delegated hit cannot apply generic damage")
		t.ok(not shot.active, "collision consumes projectile even when blocked")
		if protection == "shield":
			t.equal(victim.mods["shield"], 0.0, "shield absorbs projectile once")
		shot.queue_free()
		await host.get_tree().process_frame
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
