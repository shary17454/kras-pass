extends RefCounted

func run(t: TestHarness, host: Node) -> void:
	t.suite("boss weak point perception")
	for id in ["boss_dreadnought", "boss_sovereign", "boss_colossus"]:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build(id, ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 901), "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		for body in scene.ctx.fighters:
			body.set_physics_process(false)
		var cue: Node3D = scene.controller._vent if id == "boss_dreadnought" else (scene.controller._fist if id == "boss_colossus" else scene.controller._core)
		if id == "boss_colossus":
			scene.controller._exposed = 2.0
		if id == "boss_sovereign":
			scene.controller._recover = 2.0
		cue.global_position = Vector3(4, 1, 0)
		var brain = load("res://src/ai/brains/boss_hunter_brain.gd").new()
		brain.configure(0, scene.ctx, 2, 77)
		brain.controller = scene.controller
		brain.reaction_time = 0.5
		brain._time = 10.0
		t.ok(brain.has_method("perceived_weak_points"), id + " exposes delayed weak point observations")
		if brain.has_method("perceived_weak_points"):
			t.ok(brain.can_observe(cue), id + " actual rendered weak point is visible")
			t.empty(brain.perceived_weak_points(), id + " fresh weak point is delayed")
			brain._time = 10.49
			t.empty(brain.perceived_weak_points(), id + " reaction threshold is not rounded early")
			brain._time = 10.5
			t.equal(brain.perceived_weak_points(), [Vector3(4, 1, 0)], id + " observed weak point is actionable at threshold")
			cue.global_position = Vector3(6, 1, 0)
			brain._time = 10.6
			t.equal(brain.perceived_weak_points(), [Vector3(4, 1, 0)], id + " live movement does not bypass position delay")
			brain._time = 11.1
			t.equal(brain.perceived_weak_points(), [Vector3(6, 1, 0)], id + " delayed movement becomes available")
			var fighter: Fighter = scene.ctx.fighter(0)
			fighter.global_position = Vector3(6, 0.5, 1.5)
			brain.attack_chance = 1.0
			brain.accuracy = 1.0
			brain.bits = 0
			brain.decide(0.1)
			t.ok((brain.bits & InputFrame.Btn.ATTACK) != 0, id + " actual decision attacks an observed reachable weak point")
			cue.hide()
			t.empty(brain.perceived_weak_points(), id + " hidden weak point cannot guide attack")
			brain.bits = 0
			brain.decide(0.1)
			t.ok((brain.bits & InputFrame.Btn.ATTACK) == 0, id + " actual decision cannot attack a hidden weak point")
			cue.show()
			t.empty(brain.perceived_weak_points(), id + " reappearance cannot reuse reaction credit")
			brain._time += 0.5
			t.equal(brain.perceived_weak_points().size(), 1, id + " reappearing cue is observed after delay")
			cue.global_position = Vector3(10000, 0, 0)
			t.empty(brain.perceived_weak_points(), id + " offscreen weak point cannot guide attack")
			cue.global_position = Vector3(4, 1, 0)
			brain.perceived_weak_points()
			brain.on_round_start()
			t.empty(brain._weak_history, id + " round restart clears weak point history")
			if id == "boss_colossus":
				scene.controller._exposed = 0.0
				fighter.global_position = Vector3(10.0, 0.5, 0.0)
				brain.bits = 0
				brain.decide(0.1)
				t.ok(brain.move.x < 0.0, "closed Colossus opening repositions toward central safe ground")
				t.equal(brain.bits & InputFrame.Btn.ATTACK, 0, "staging cannot attack a closed weak point")
				var partner: Fighter = scene.ctx.fighter(1)
				partner.global_position = fighter.global_position + Vector3(-1.0, 0.0, 0.0)
				scene.ctx.fighter(2).hide()
				scene.ctx.fighter(3).hide()
				brain.reaction_time = 0.0
				brain.aggression = 1.0
				brain.edge_awareness = 0.0
				brain._record_history()
				brain.bits = 0
				brain.decide(0.1)
				t.equal(brain.bits & InputFrame.Btn.ATTACK, 0, "closed Colossus window does not switch to attacking nearby participants")
				scene.controller._open_crater(Vector3.ZERO, 4.0)
				fighter.global_position = Vector3(3.45, 0.5, 0.0)
				brain.edge_awareness = 1.0
				brain.dash_chance = 1.0
				brain.bits = 0
				brain.decide(0.1)
				t.equal(brain.bits & InputFrame.Btn.DASH, 0, "a small persistent crater clearance correction does not request a long dash")
				t.ok(brain.move.length() < 0.6, "persistent crater correction brakes near safe ground instead of fleeing at full speed")
			if id == "boss_sovereign":
				scene.controller._shielded = true
				t.empty(brain.perceived_weak_points(), "shielded core is not a weak point")
				scene.controller._shielded = false
				brain.perceived_weak_points()
				brain._time += 0.5
				brain.perceived_weak_points()
				scene.controller._recover = 0.0
				t.empty(brain.perceived_weak_points(), "closed recovery window clears core observation")
				var orb := MeshFactory.sphere(0.5, Color.WHITE)
				scene.add_child(orb)
				orb.global_position = Vector3(3, 1, 0)
				scene.controller.phase = 1
				scene.controller._shielded = true
				scene.controller._orbs.append({"node": orb, "returned": false})
				t.equal(scene.controller.weak_points(), [orb.global_position], "position interface preserves the exposed orb objective")
				t.empty(brain.perceived_weak_points(), "new orb objective starts its own reaction delay")
				brain._time += 0.5
				t.equal(brain.perceived_weak_points(), [orb.global_position], "visible orb becomes actionable independently of shielded core")
				scene.controller._orbs.back().returned = true
				t.empty(brain.perceived_weak_points(), "returned orb cannot remain an attack target")
			for index in 100:
				brain._time += 0.05
				brain.perceived_weak_points()
			for samples in brain._weak_history.values():
				t.ok(samples.size() <= AIBrain.HISTORY_CAP, id + " observed sample history is bounded")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
		await host.get_tree().process_frame
