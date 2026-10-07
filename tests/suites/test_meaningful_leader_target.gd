extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("meaningful AI leader targeting")
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": MatchConfig.build("scrap_karts", ["fanoos", "nabta", "ramla", "sakhra"], 0, 3, 829)})
	scene.set_physics_process(false)
	for fighter in scene.ctx.fighters:
		fighter.set_physics_process(false)
		scene.ctx.fighter(fighter.slot).global_position = Vector3(fighter.slot * 3, 1, 0)
	for difficulty in 4:
		var brain := AIBrain.new()
		brain.configure(0, scene.ctx, difficulty, 829)
		brain.on_round_start()
		t.equal(brain.priority_rival(), -1, "tier %d cannot target before perception delay" % difficulty)
		# Test score selection independently of timing; production profiles remain unchanged.
		brain.reaction_time = 0.0
		brain.strategy = 1.0
		scene.ctx.scores.fill(0)
		var reference := RandomNumberGenerator.new()
		reference.seed = brain.rng.seed
		reference.state = brain.rng.state
		reference.randi_range(0, 2) # Three visible co-leaders in this fixture.
		reference.randf()
		brain.priority_rival()
		t.equal(brain.rng.state, reference.state, "tied target selection preserves the established random draw budget")
		for score in [0, 7, -7]:
			scene.ctx.scores.fill(score)
			for sample in 64:
				t.equal(brain.priority_rival(), 1, "equal visible scores cannot invent a distant leader")
		scene.ctx.scores.assign([0, 9, 2, 9])
		for sample in 64:
			t.equal(brain.priority_rival(), 1, "nearest co-leader is not displaced by an equally scoring farther rival")
		scene.ctx.scores.assign([0, 0, 0, 20])
		var leader_selections := 0
		for sample in 64:
			if brain.priority_rival() == 3:
				leader_selections += 1
		t.ok(leader_selections > 50, "actual visible lead still attracts strategic targeting")
		scene.ctx.fighter(3).hide()
		for sample in 16:
			t.equal(brain.priority_rival(), 1, "hidden score leader cannot displace nearest eligible rival")
		scene.ctx.fighter(3).show()
		scene.ctx.alive[3] = false
		for sample in 16:
			t.equal(brain.priority_rival(), 1, "eliminated score leader cannot displace nearest eligible rival")
		scene.ctx.alive[3] = true
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
