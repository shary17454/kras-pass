extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("tide ordinary jump access")
	await _jump_braking_input(t, host)
	for character in Registry.characters():
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("rising_tide", [character.id], 1, 3, 807)})
		scene.set_physics_process(false)
		var body: Fighter = scene.ctx.fighter(0)
		body.set_physics_process(false)
		body.control_enabled = true
		var steps: Array[Node3D] = []
		for node in scene.arena.get_node("Static").get_children():
			if node is StaticBody3D and node.position.y > 0.0:
				steps.append(node)
		steps.sort_custom(func(a, b): return a.position.y < b.position.y)
		t.equal(steps.size(), 25, "tide has three eight-ledge tiers and one summit")
		if character.id == "nabta":
			for step in steps:
				if step.name == "Summit":
					continue
				var rotated := Vector3(-step.position.z, step.position.y, step.position.x)
				t.ok(steps.any(func(other): return other.position.distance_to(rotated) < 0.001), "every tide ledge has a quarter-turn counterpart")
		var first := steps[0]
		var outward := Vector3(first.position.x, 0, first.position.z).normalized()
		body.global_position = Vector3(first.position.x, 0.05, first.position.z) + outward * 3.1
		body.velocity = Vector3.ZERO
		var start := body.global_position
		for tick in 20:
			await host.get_tree().physics_frame
			body.tick(InputFrame.new(), 1.0 / 60.0)
		t.ok(body.is_on_floor(), "%s starts on actual floor" % character.id)
		var previous_height := 0.0
		for tier in 4:
			var target: Node3D = null
			var nearest := INF
			var tier_height := INF
			for step in steps:
				if step.position.y > previous_height + 0.1:
					tier_height = minf(tier_height, step.position.y)
			for step in steps:
				if absf(step.position.y - tier_height) > 0.01:
					continue
				var distance := body.global_position.distance_to(step.global_position)
				if distance < nearest:
					nearest = distance
					target = step
			var landed := false
			for tick in 240:
				await host.get_tree().physics_frame
				var flat := Vector2(target.global_position.x - body.global_position.x, target.global_position.z - body.global_position.z)
				var frame := InputFrame.new()
				frame.move = flat.limit_length(1.0)
				if body.is_on_floor() and body.global_position.y < target.global_position.y and flat.length() < 3.2:
					frame.bits = InputFrame.Btn.JUMP
				body.tick(frame, 1.0 / 60.0)
				if body.is_on_floor() and body.global_position.y >= target.global_position.y + 0.2 and flat.length() < 1.0:
					landed = true
					break
			t.ok(landed, "%s lands on tier %d with ordinary input, y=%.2f" % [character.id, tier + 1, body.global_position.y])
			if not landed:
				break
			previous_height = target.position.y
		# Isolate ordinary climbing decisions from rival attacks and water.
		# The natural campaign separately uses the actual camera and hazards.
		body.respawn_at(start)
		body.control_enabled = true
		scene.ctx.observation_camera = null
		var brain = load("res://src/ai/brains/climber_brain.gd").new()
		brain.configure(0, scene.ctx, 3, 807)
		brain.aggression = 0.0
		brain.on_round_start()
		var reaction: float = brain.reaction_time
		brain.reaction_time = 0.0
		var selected: Vector3 = brain._find_higher_ground(body.global_position)
		t.near(selected.y, first.position.y + 0.25, 0.001, "%s selects a reachable solid first step, not summit or decorative rim" % character.id)
		body.can_jump = false
		t.equal(brain._find_higher_ground(body.global_position), body.global_position, "disabled jump does not plan an elevated route")
		body.can_jump = true
		brain.reaction_time = reaction
		for spawn in 4:
			brain.on_round_start()
			body.respawn_at(scene.arena.spawn_points[spawn])
			body.control_enabled = true
			var reached := false
			var last_bits := 0
			for tick in 1200:
				await host.get_tree().physics_frame
				brain._time += 1.0 / 60.0
				brain.bits = 0
				brain.decide(1.0 / 60.0)
				var frame := InputFrame.new()
				frame.move = brain.move
				frame.bits = brain.bits
				frame.prev_bits = last_bits
				last_bits = frame.bits
				body.tick(frame, 1.0 / 60.0)
				if body.is_on_floor() and body.global_position.y >= steps.back().position.y + 0.2:
					reached = true
					break
			t.ok(reached, "%s AI climbs from actual spawn %d, y=%.2f" % [character.id, spawn, body.global_position.y])
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
	var duel: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(duel)
	duel.setup({"config": MatchConfig.build("duel_pit", ["fanoos"], 1, 3, 807)})
	duel.set_physics_process(false)
	var first_height := INF
	for node in duel.arena.get_node("Static").get_children():
		if node is StaticBody3D and node.position.y > 0.0:
			first_height = minf(first_height, node.position.y)
	t.near(first_height, 2.3, 0.001, "unrelated duel pit keeps original tier heights")
	t.near(duel.arena.get_node("Static/Summit").position.y, 9.1, 0.001, "unrelated duel pit keeps original summit")
	duel.teardown()
	duel.queue_free()
	await host.get_tree().process_frame


func _jump_braking_input(t: TestHarness, host: Node) -> void:
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": MatchConfig.build("rising_tide", ["fanoos"], 1, 3, 807)})
	scene.set_physics_process(false)
	var body: Fighter = scene.ctx.fighter(0)
	body.set_physics_process(false)
	body.control_enabled = true
	for tick in 20:
		await host.get_tree().physics_frame
		body.tick(InputFrame.new(), 1.0 / 60.0)
	t.ok(body.is_on_floor(), "jump braking fixture is on the actual tide floor")
	for difficulty in 4:
		var brain = load("res://src/ai/brains/climber_brain.gd").new()
		brain.configure(0, scene.ctx, difficulty, 807)
		brain.on_round_start()
		brain._ledge_target = body.global_position + Vector3(3.5, 1.35, 0)
		brain.move = Vector2.ZERO
		brain.bits = InputFrame.Btn.ATTACK
		brain._publish()
		t.equal(InputRouter._virtual_pending[0].move, Vector2.ZERO, "tier %d jump preparation publishes an actual stop despite input noise" % difficulty)
		t.equal(InputRouter._virtual_pending[0].bits, InputFrame.Btn.ATTACK, "jump braking preserves unrelated actions")
		brain.move = Vector2.RIGHT
		brain._publish()
		t.ok(InputRouter._virtual_pending[0].move.length() > 0.5, "jump approach remains enabled")
		brain.move = Vector2.ZERO
		brain._prepare_jump = false
		brain._publish()
		t.ok(InputRouter._virtual_pending[0].move.length() > 0.0, "ordinary movement retains difficulty input noise")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
