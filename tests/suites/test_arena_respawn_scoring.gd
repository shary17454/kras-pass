extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("arena respawn scoring")
	for id in ["duel_pit", "bumper_bowl", "duo_clash"]:
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
		if id == "duo_clash":
			t.equal(game.team_score(0), 2, "legitimate enemy ring-out pays the team once")
			t.equal(scene.ctx.scores[0], 2, "attacker receives shared team score")
			t.equal(scene.ctx.scores[2], 2, "partner receives the same team score")
			var partner: Fighter = scene.ctx.fighter(2)
			partner._invuln = 0.0
			t.ok(not partner.take_hit(0, Vector3.FORWARD, 1.0, 10.0), "partner cannot damage or push a teammate")
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
		if id == "duo_clash":
			t.equal(game.team_score(0), 4, "second legitimate enemy ring-out pays the team once")
			t.equal(game.compute_scores()[0], 42, "team result includes exactly two personal knockouts")
		if id == "bumper_bowl":
			var waiting_score: int = scene.ctx.scores[1]
			var survivor_score: int = scene.ctx.scores[3]
			game.on_fighter_fell(2)
			t.equal(scene.ctx.scores[1], waiting_score, "absent fighter cannot collect survival points while awaiting respawn")
			t.equal(scene.ctx.scores[3], survivor_score + 1, "fighter still in bowl receives survival point")
			game.process_respawns(game.respawn_delay + 0.1)
			t.ok(victim.alive and victim.visible, "waiting survivor returns to bowl")
			game.on_fighter_fell(2)
			t.equal(scene.ctx.scores[1], waiting_score + 1, "returned fighter can earn survival points again")
			for round_index in 3:
				var bumpers: Array = []
				for hazard in scene.arena._hazards:
					if hazard is ArenaHazards.Bumper:
						bumpers.append(hazard)
						hazard._cooldowns[0] = 0.4
						hazard.play_feedback()
						var previous: Tween = hazard._bounce_tween
						hazard.play_feedback()
						t.ok(not previous.is_valid(), "repeated bounce replaces previous visual tween")
						hazard._mesh.scale = Vector3(1.25, 0.8, 1.25)
				t.equal(bumpers.size(), 5, "all five authored bumpers covered")
				scene.arena.reset_hazards()
				for bumper in bumpers:
					t.ok(bumper._cooldowns.is_empty(), "new round clears bumper hit immunity")
					t.equal(bumper._mesh.scale, Vector3.ONE, "new round restores bumper shape")
					t.ok(bumper._bounce_tween == null, "new round cancels pending visual animation")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
