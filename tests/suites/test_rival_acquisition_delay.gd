extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("first rival observation delay")
	for difficulty in 4:
		t.test("tier %d first acquisition and restart" % difficulty)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("ring_rumble", ["fanoos", "nabta", "ramla", "sakhra"], 0, difficulty, 723), "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		for body in scene.ctx.fighters:
			body.set_physics_process(false)
		scene.ctx.observation_camera = null
		var me: Fighter = scene.ctx.fighter(0)
		var rival: Fighter = scene.ctx.fighter(1)
		me.global_position = Vector3(scene.arena.def.radius - 1.5, 0.8, 0)
		rival.global_position = me.global_position + Vector3(0.6, 0, 0)
		rival.velocity = Vector3(7, 0, 0)
		for slot in [2, 3]:
			scene.ctx.fighter(slot).hide()
		scene.ctx.scores[1] = 10
		var brain := AIBrain.new()
		brain.configure(0, scene.ctx, difficulty, 723)
		brain.attack_chance = 1.0
		brain.edge_awareness = 1.0
		brain._time = 10.0
		brain._record_history()
		_check_unready(t, brain, difficulty, "first sample")
		brain._time = 10.0 + brain.reaction_time - 0.0001
		_check_unready(t, brain, difficulty, "before deadline")
		brain._time = 10.0 + brain.reaction_time
		t.equal(brain.nearest_rival(), 1, "tier %d acquires closest rival at reaction deadline" % difficulty)
		t.equal(brain.leader_rival(), 1, "tier %d acquires leader at reaction deadline" % difficulty)
		t.equal(brain.edge_pressured_rival(), 1, "tier %d reads rival edge pressure at deadline" % difficulty)
		t.equal(brain.perceive(1), rival.global_position, "tier %d observes recorded position after delay" % difficulty)
		brain.maybe_attack(1, 2.0)
		t.ok((brain.bits & InputFrame.Btn.ATTACK) != 0, "tier %d can attack acquired rival" % difficulty)
		brain.on_round_start()
		_check_unready(t, brain, difficulty, "round restart")
		brain.reaction_time = 0.0
		t.equal(brain.nearest_rival(), 1, "explicit zero delay preserves immediate visible targeting")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame


func _check_unready(t: TestHarness, brain: AIBrain, difficulty: int, stage: String) -> void:
	var label := "tier %d %s" % [difficulty, stage]
	t.equal(brain.nearest_rival(), -1, label + " cannot acquire nearest rival early")
	t.equal(brain.leader_rival(), -1, label + " cannot acquire leader early")
	t.equal(brain.priority_rival(), -1, label + " cannot bypass acquisition through priority")
	t.equal(brain.edge_pressured_rival(), -1, label + " cannot acquire edge target early")
	t.equal(brain.perceive(1), Vector3.ZERO, label + " cannot expose first live position early")
	t.equal(brain._perceived_velocity(1), Vector3.ZERO, label + " cannot expose first live velocity early")
	brain.bits = 0
	brain.maybe_attack(1, 2.0)
	t.equal(brain.bits, 0, label + " cannot attack unprocessed target")
