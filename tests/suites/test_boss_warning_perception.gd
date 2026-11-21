extends RefCounted

func run(t: TestHarness, host: Node) -> void:
	t.suite("boss visible warning reaction delay")
	for id in ["boss_forge", "boss_colossus", "boss_dreadnought", "boss_sovereign"]:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build(id, ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 901), "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		for body in scene.ctx.fighters:
			body.set_physics_process(false)
		scene.controller.telegraph(Vector3.ZERO, 3.0, 2.0, func(_p, _r): pass)
		var cue: Node3D = scene.controller._telegraphs.back().node
		var brain = load("res://src/ai/brains/boss_hunter_brain.gd").new()
		brain.configure(0, scene.ctx, 2, 77)
		brain.controller = scene.controller
		brain.reaction_time = 0.5
		brain._time = 10.0
		t.ok(brain.can_observe(cue), id + " actual warning is visible in fixture")
		t.empty(brain.perceived_dangers(), id + " newly visible warning cannot trigger immediate reaction")
		brain._time = 10.49
		t.empty(brain.perceived_dangers(), id + " warning remains delayed before reaction threshold")
		brain._time = 10.5
		t.equal(brain.perceived_dangers().size(), 1, id + " visible warning becomes actionable at threshold")
		var live: Dictionary = scene.controller._telegraphs.back()
		live.pos = Vector3(1, 0, 0)
		cue.global_position = live.pos
		live.radius = 4.0
		live.left = 1.4
		brain._time = 10.6
		var delayed: Dictionary = brain.perceived_dangers()[0]
		t.equal(delayed.pos, Vector3.ZERO, id + " mature warning movement still respects reaction delay")
		t.near(delayed.radius, 3.0, 0.001, id + " mature warning size still comes from delayed observation")
		delayed.pos = Vector3(999, 0, 0)
		t.equal(brain.perceived_dangers()[0].pos, Vector3.ZERO, id + " returned danger cannot mutate retained observations")
		brain._time = 11.1
		var updated: Dictionary = brain.perceived_dangers()[0]
		t.equal(updated.pos, Vector3(1, 0, 0), id + " visible warning movement becomes actionable after delay")
		t.near(updated.radius, 4.0, 0.001, id + " visible warning size becomes actionable after delay")
		t.near(updated.left, 0.9, 0.001, id + " remaining warning time advances from the observed countdown")
		cue.hide()
		t.empty(brain.perceived_dangers(), id + " hidden warning cannot guide escape")
		t.empty(brain._danger_seen, id + " hidden warning loses prior reaction credit")
		cue.show()
		t.empty(brain.perceived_dangers(), id + " reappearing cue starts a fresh delay")
		brain._time += brain.reaction_time
		t.equal(brain.perceived_dangers().size(), 1, id + " reappearing cue becomes actionable after delay")
		brain.on_round_start()
		t.empty(brain._danger_seen, id + " new round clears warning observations")
		cue.global_position = Vector3(10000, 0, 0)
		t.empty(brain.perceived_dangers(), id + " off-screen warning is not perceived")
		cue.global_position = Vector3.ZERO
		brain.perceived_dangers()
		brain.reaction_time = 0.0
		for sample in AIBrain.HISTORY_CAP + 3:
			brain._time += 0.1
			brain.perceived_dangers()
		t.equal(brain._danger_seen[cue.get_instance_id()].size(), AIBrain.HISTORY_CAP, id + " danger observation history stays bounded")
		t.equal(brain.perceived_dangers()[0].pos, live.pos, id + " zero delay uses the latest visible geometry")
		brain.reaction_time = 0.5
		scene.controller._clear_telegraphs()
		t.empty(brain.perceived_dangers(), id + " removed cue cannot persist")
		if id == "boss_colossus":
			var fighter: Fighter = scene.ctx.fighter(0)
			fighter.global_position = Vector3(7.55, 0, 0)
			scene.controller._fist.global_position = Vector3(4, 1, 0)
			scene.controller._exposed = 1.0
			scene.controller._open_crater(Vector3(4, 0, 0), 4.0)
			scene.controller.telegraph(Vector3(6.55, 0, 0), 4.0, 2.0, func(_p, _r): pass)
			brain.edge_awareness = 1.0
			brain.accuracy = 1.0
			brain.attack_chance = 1.0
			# Isolate the new warning's delay from the already observed fist.
			brain.perceived_weak_points()
			brain._time += brain.reaction_time
			brain.bits = 0
			brain.decide(0.1)
			brain._publish_output(brain.move)
			InputRouter._physics_process(0.0)
			t.ok(InputRouter.frame(0).held(InputFrame.Btn.ATTACK), "fresh warning does not bypass reaction delay in actual decision")
			brain._time += 0.5
			brain.bits = 0
			brain.decide(0.1)
			brain._publish_output(brain.move)
			InputRouter._physics_process(0.0)
			t.ok(not InputRouter.frame(0).held(InputFrame.Btn.ATTACK), "perceived warning preempts attack after actual reaction delay")
			t.ok(brain.move.x > 0.0, "actual decision flees perceived warning")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
		await host.get_tree().process_frame
