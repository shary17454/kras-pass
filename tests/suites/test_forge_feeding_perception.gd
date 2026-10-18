extends RefCounted

func run(t: TestHarness, host: Node) -> void:
	t.suite("forge feeding perception")
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": MatchConfig.build("boss_forge", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 901), "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	for body in scene.ctx.fighters: body.set_physics_process(false)
	scene.controller._lob_crate()
	var crate: Node3D = scene.controller._crates.back()
	crate.global_position = Vector3(4, 0.7, 0)
	var fighter: Fighter = scene.ctx.fighter(0)
	fighter.global_position = Vector3(5.5, 0.5, 0)
	var brain = load("res://src/ai/brains/boss_hunter_brain.gd").new()
	brain.configure(0, scene.ctx, 2, 77)
	brain.controller = scene.controller
	brain.attack_chance = 1.0
	brain.accuracy = 1.0
	brain.reaction_time = 0.5
	brain._time = 10.0
	crate.hide()
	brain.decide(0.1)
	t.ok(not _attack_requested(brain), "actual decision cannot feed a hidden crate")
	t.ok(brain.has_method("perceived_feeding_targets"), "feeding targets have an observation interface")
	if brain.has_method("perceived_feeding_targets"):
		crate.show()
		t.empty(brain.perceived_feeding_targets().crates, "new crate starts a reaction delay")
		brain._time += 0.49
		t.empty(brain.perceived_feeding_targets().crates, "crate is not actionable before the threshold")
		brain._time += 0.01
		t.equal(brain.perceived_feeding_targets().crates, [crate.global_position], "crate is actionable at the threshold")
		brain.bits = 0
		brain.decide(0.1)
		t.ok(_attack_requested(brain), "observed aligned crate can be fed by actual decision")
		crate.global_position = Vector3(6, 0.7, 0)
		brain._time += 0.1
		t.equal(brain.perceived_feeding_targets().crates, [Vector3(4, 0.7, 0)], "crate movement uses a delayed position")
		crate.hide()
		t.empty(brain.perceived_feeding_targets().crates, "hidden crate loses observation credit")
		scene.controller._spawn_slag(Vector3(4, 0.7, 0), 0)
		var slag: Node3D = scene.controller._slag.back().node
		t.empty(brain.perceived_feeding_targets().slag, "new hot slag starts its own reaction delay")
		brain._time += 0.5
		var observed: Dictionary = brain.perceived_feeding_targets()
		t.equal(observed.slag, [slag.global_position], "visible hot slag becomes actionable")
		t.ok(scene.controller.feeding_plan(fighter.global_position, observed).hot, "observed hot slag retains feeding priority")
		slag.global_position = Vector3(10000, 0, 0)
		t.empty(brain.perceived_feeding_targets().slag, "offscreen slag cannot guide feeding")
		slag.global_position = Vector3(4, 0.7, 0)
		brain.perceived_feeding_targets()
		crate.show()
		for index in 100:
			brain._time += 0.05
			brain.perceived_feeding_targets()
		for history: Dictionary in brain._feeding_history.values():
			for samples: Array in history.values():
				t.ok(samples.size() <= AIBrain.HISTORY_CAP, "feeding observation samples remain bounded")
		brain.on_round_start()
		t.empty(brain._feeding_history, "round restart clears feeding observations")
		brain.perceived_feeding_targets()
		slag.queue_free()
		await host.get_tree().process_frame
		t.empty(brain.perceived_feeding_targets().slag, "removed slag cannot remain a target")
		t.empty(scene.controller.feeding_plan(fighter.global_position, {"slag": [], "crates": []}), "empty observations never fall back to live items")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame


func _attack_requested(brain: AIBrain) -> bool:
	brain._publish_output(brain.move)
	InputRouter._physics_process(0.0)
	return InputRouter.frame(brain.slot).held(InputFrame.Btn.ATTACK)
