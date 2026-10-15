extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("survival winner contract")
	for count in range(2, 5):
		for survivor in count:
			var characters: Array[String] = ["fanoos", "nabta", "ramla", "sakhra"]
			characters.resize(count)
			var scene: Node = load("res://src/match/match_scene.gd").new()
			host.add_child(scene)
			scene.setup({"config": MatchConfig.build("scrap_karts", characters, 0, 3, 820)})
			scene.set_physics_process(false)
			for fighter in scene.ctx.fighters:
				fighter.set_physics_process(false)
			var hunter := (survivor + 1) % count
			for slot in count:
				if slot != survivor and slot != hunter:
					scene.ctx.eliminate(slot)
			# The hunter wrecks everyone else, then the survivor wrecks the hunter.
			scene.ctx.details[hunter]["knockouts"] = count - 2
			scene.ctx.details[survivor]["knockouts"] = 1
			scene.ctx.eliminate(hunter)
			var scores: Array[int] = scene.controller.compute_scores()
			var result := MatchResult.make("scrap_karts", scene.ctx.config.arena_id, scores, true)
			t.equal(result.winners(), [survivor], "last kart wins for every player count and spawn slot")
			t.ok(not scene.controller.is_tied(), "eliminated hunter cannot force sudden death")
			t.equal(scene.ctx.details[hunter]["knockouts"], count - 2, "knockout statistics remain intact")
			t.equal(scene.controller.compute_scores(), scores, "result calculation is repeatable")
			if count == 4 and survivor == 0:
				_check_timeout_and_empty_round(t, scene)
			scene.teardown()
			scene.queue_free()
			await host.get_tree().process_frame


func _check_timeout_and_empty_round(t: TestHarness, scene: Node) -> void:
	for slot in 4:
		scene.ctx.revive(slot)
	var unchanged: Array[int] = [8, 6, 2, 4]
	t.equal(scene.controller._prioritize_survivors(unchanged.duplicate()), unchanged, "no eliminations leave score rules unchanged")
	scene.ctx.eliminate(2)
	scene.ctx.eliminate(3)
	var raw: Array[int] = [5, 20, 15, 10]
	var lifted: Array[int] = scene.controller._prioritize_survivors(raw.duplicate())
	t.ok(lifted[0] > lifted[2] and lifted[1] > lifted[2], "every timeout survivor outranks eliminated hunters")
	t.equal(lifted[1] - lifted[0], 15, "common lift preserves relative knockout rewards among survivors")
	var tied: Array[int] = [5, 5, 15, 10]
	var result := MatchResult.make("scrap_karts", scene.ctx.config.arena_id, scene.controller._prioritize_survivors(tied), true)
	t.equal(result.winners(), [0, 1], "timeout ties remain ties among survivors")
	scene.ctx.eliminate(0)
	scene.ctx.eliminate(1)
	t.equal(scene.controller._prioritize_survivors(raw.duplicate()), raw, "all eliminated preserves elimination and bonus ordering")
