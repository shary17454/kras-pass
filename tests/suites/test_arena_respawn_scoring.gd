extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("arena respawn scoring")
	for id in ["duel_pit", "bumper_bowl"]:
		var cfg := MatchConfig.build(id, ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 117)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": cfg, "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		var game = scene.controller
		game.on_round_start()
		var victim: Fighter = scene.ctx.fighter(1)
		victim._invuln = 0.0
		t.ok(victim.take_hit(0, Vector3.FORWARD, 1.0, 10.0), "fixture establishes legitimate attacker")
		game.on_fighter_fell(1)
		t.equal(int(scene.ctx.details[0].get("knockouts", 0)), 1, "one ring-out credits one knockout")
		t.equal(int(scene.ctx.details[1].get("falls", 0)), 1, "one fall recorded")
		var lives: int = game.lives(1)
		var scores: Array = Array(scene.ctx.scores).duplicate()
		game.on_fighter_knocked_out(1, 0)
		t.equal(game.lives(1), lives, "duplicate callback cannot spend another life")
		t.equal(Array(scene.ctx.scores), scores, "duplicate callback cannot pay survivors or attacker again")
		t.equal(int(scene.ctx.details[0].get("knockouts", 0)), 1, "duplicate callback cannot credit another knockout")
		t.equal(int(scene.ctx.details[1].get("falls", 0)), 1, "duplicate callback cannot add another fall")
		game.process_respawns(game.respawn_delay + 0.1)
		t.ok(victim.alive and victim.visible, "player returns after delay")
		t.equal(victim.damage_percent, 0.0, "respawn clears damage")
		if id == "duel_pit":
			t.equal(game.lives(1), 2, "duel spends exactly one of three lives")
			t.equal(game.compute_scores()[0], 31, "duel score includes exactly one knockout")
		victim._invuln = 0.0
		t.ok(victim.take_hit(0, Vector3.FORWARD, 1.0, 10.0), "new life accepts a new hit")
		game.on_fighter_fell(1)
		t.equal(int(scene.ctx.details[0].get("knockouts", 0)), 2, "new life can earn a second legitimate knockout")
		t.equal(int(scene.ctx.details[1].get("falls", 0)), 2, "new life records its own fall")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
