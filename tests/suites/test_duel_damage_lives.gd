extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("duel damage accumulates without spending lives")
	var rosters: Array[Array] = [
		["nabta", "sakhra", "fanoos", "ramla"],
		["barq", "mowja", "ghaim", "turs"],
	]
	for roster in rosters:
		var characters: Array[String] = []
		characters.assign(roster)
		var cfg := MatchConfig.build("duel_pit", characters, 0, 2, 117)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": cfg})
		scene.set_physics_process(false)
		scene.phase = MatchPhase.P.PLAYING
		scene.controller.on_round_start()
		for slot in 4:
			var fighter: Fighter = scene.ctx.fighter(slot)
			fighter.set_physics_process(false)
			fighter._invuln = 0.0
			t.ok(fighter.take_hit((slot + 1) % 4, Vector3.RIGHT, 1.0, 150.0),
				"real fighter accepts accumulated damage")
			t.equal(fighter.damage_percent, 150.0, "damage can exceed base health")
			t.equal(scene.controller.lives(slot), 3, "damage alone cannot spend a duel life")
			t.ok(fighter.alive, "damaged duellist remains active")
			var first_push := fighter._impulse.x
			fighter._impulse = Vector3.ZERO
			fighter._invuln = 0.0
			fighter.take_hit((slot + 1) % 4, Vector3.RIGHT, 1.0, 1.0)
			t.ok(fighter._impulse.x > first_push, "accumulated damage increases the next push")
			scene.controller.on_fighter_fell(slot)
			t.equal(scene.controller.lives(slot), 2, "fall still spends one life")
			t.equal(fighter.damage_percent, 0.0, "fall clears accumulated damage")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
	var cfg := MatchConfig.build("ring_rumble", ["nabta", "sakhra", "fanoos", "ramla"], 0, 2, 117)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg})
	scene.set_physics_process(false)
	scene.phase = MatchPhase.P.PLAYING
	var fighter: Fighter = scene.ctx.fighter(0)
	fighter.set_physics_process(false)
	var defeats: Array[int] = []
	fighter.knocked_out.connect(func(slot: int, _by: int): defeats.append(slot))
	fighter._invuln = 0.0
	fighter.take_hit(1, Vector3.RIGHT, 1.0, 150.0)
	t.equal(defeats, [0], "other games retain health-based defeat")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
