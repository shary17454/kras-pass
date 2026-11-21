extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("dodger delayed visible arm motion")
	var arena := Arena.new()
	host.add_child(arena)
	var arm := ArenaHazards.Sweeper.new()
	arena.add_child(arm)
	arm.build(Color.WHITE, 8.0, 0.85)
	var ctx := MatchContext.new()
	ctx.arena = arena
	ctx.config = MatchConfig.build("sweeper_storm", ["fanoos"], 0, 1, 119)
	var brain = load("res://src/ai/brains/dodger_brain.gd").new()
	brain.configure(0, ctx, 3, 119)
	brain.reaction_time = 0.5
	brain.prediction = 0.0
	brain.edge_awareness = 1.0
	var target := Vector3.RIGHT.rotated(Vector3.UP, 0.5) * 3.0
	t.ok(brain._incoming_arm(arena, target).is_empty(), "unobserved arm cannot trigger a dodge")
	brain._record_history()
	brain._time = 0.1
	arm.rotation.y = 0.1
	brain._record_history()
	t.ok(brain._incoming_arm(arena, target).is_empty(), "new visible motion waits for reaction delay")
	brain._time = 0.6
	var threat: Dictionary = brain._incoming_arm(arena, target)
	t.ok(not threat.is_empty(), "two visible samples provide an actionable trajectory after delay")
	if not threat.is_empty():
		t.near(float(threat["eta"]), 0.4, 0.001, "arrival derives from successive visible transforms")
	arm.speed = 80.0
	arm._age = 90.0
	arm.accel_over_time = 20.0
	arm.rotation.y = 0.4
	threat = brain._incoming_arm(arena, target)
	t.ok(not threat.is_empty(), "private scheduling does not remove an observed threat")
	if not threat.is_empty():
		t.near(float(threat["eta"]), 0.4, 0.001, "unsampled motion and private angular speed cannot override perception")
	arm.hide()
	t.ok(brain._incoming_arm(arena, target).is_empty(), "hidden arm is not actionable")
	arm.show()
	var mesh := arm.get_child(0) as MeshInstance3D
	mesh.hide()
	t.ok(brain._incoming_arm(arena, target).is_empty(), "hidden rendered mesh cannot reveal an arm")
	mesh.show()
	arm.length = 100.0
	t.ok(brain._incoming_arm(arena, target.normalized() * 12.0).is_empty(), "private collision reach cannot reveal a longer visible arm")
	brain.on_round_start()
	t.ok(brain._incoming_arm(arena, target).is_empty(), "round restart discards previous arm trajectory")
	_test_signed_motion(t, brain, arena, arm)
	_test_visibility_gap(t, brain, arena, arm)
	_test_history_capacity(t, brain, arena, arm)
	_test_prediction(t, brain, arena, arm)
	_test_own_velocity(t, brain, arena, arm)
	arena.queue_free()
	await host.get_tree().process_frame


func _test_own_velocity(t: TestHarness, brain, arena: Arena, arm: ArenaHazards.Sweeper) -> void:
	t.test("arrival relative to own observable movement")
	var body := Fighter.new()
	arena.add_child(body)
	body.set_physics_process(false)
	brain.ctx.fighters.append(body)
	brain.reaction_time = 0.5
	brain.prediction = 0.0
	brain.edge_awareness = 1.0
	for angle in [0.0, 0.7, -1.4]:
		for direction in [-1.0, 1.0]:
			brain.on_round_start()
			brain._time = 0.0
			arm.rotation.y = angle
			brain._record_history()
			brain._time = 0.1
			arm.rotation.y += direction * 0.1
			brain._record_history()
			brain._time = 0.6
			var target := Vector3.RIGHT.rotated(Vector3.UP, angle + direction * 0.5) * 3.0
			body.position = target
			var tangent := Vector3.UP.cross(target.normalized())
			for angular_motion in [-0.5, 0.0, 0.5]:
				body.velocity = tangent * 3.0 * direction * angular_motion
				var threat: Dictionary = brain._incoming_arm(arena, target)
				t.ok(not threat.is_empty(), "visible arm approach remains actionable with own movement")
				if not threat.is_empty():
					t.near(float(threat.eta), 0.4 / (1.0 - angular_motion), 0.001, "arrival accounts for own tangential velocity without reading rival or schedule state")
			body.velocity = tangent * 3.0 * direction
			t.ok(brain._incoming_arm(arena, target).is_empty(), "equal angular motion is not a closing encounter")
			arm.hide()
			body.velocity = -tangent * 3.0 * direction
			t.ok(brain._incoming_arm(arena, target).is_empty(), "own velocity cannot reveal a hidden arm")
			arm.show()
	brain.ctx.fighters.clear()


func _test_signed_motion(t: TestHarness, brain, arena: Arena, arm: ArenaHazards.Sweeper) -> void:
	for difficulty in range(4):
		brain.configure(0, brain.ctx, difficulty, 119)
		brain.prediction = 0.0
		for angle in [-2.95, 0.0, 2.95]:
			for direction in [-1.0, 1.0]:
				brain.on_round_start()
				arm.rotation.y = angle
				brain._time = 1.0
				brain._record_history()
				brain._time = 1.1
				arm.rotation.y = angle + direction * 0.1
				brain._record_history()
				brain._time = 1.1 + brain.reaction_time + 0.00001
				var target := Vector3.RIGHT.rotated(Vector3.UP, angle + direction * 0.5) * 3.0
				var threat: Dictionary = brain._incoming_arm(arena, target)
				t.ok(not threat.is_empty(), "all tiers infer signed rotation including wrapped angles")
				if not threat.is_empty():
					t.near(float(threat["eta"]), 0.4, 0.001, "signed rendered motion produces the same ETA in both directions")
				var behind := Vector3.RIGHT.rotated(Vector3.UP, angle - direction * 0.2) * 3.0
				t.ok(brain._incoming_arm(arena, behind).is_empty(), "arm moving away is not an imminent threat")


func _test_visibility_gap(t: TestHarness, brain, arena: Arena, arm: ArenaHazards.Sweeper) -> void:
	brain.on_round_start()
	brain.reaction_time = 0.0
	arm.rotation.y = 0.0
	brain._time = 2.0
	brain._record_history()
	var target := Vector3.RIGHT.rotated(Vector3.UP, 0.5) * 3.0
	t.ok(brain._incoming_arm(arena, target).is_empty(), "a single frame cannot reveal angular velocity")
	brain._time = 2.1
	brain._record_history()
	t.ok(brain._incoming_arm(arena, target).is_empty(), "stationary rendered arm cannot use private speed to predict a hit")
	arm.hide()
	brain._time = 2.2
	brain._record_history()
	arm.rotation.y = 0.3
	arm.show()
	brain._time = 2.3
	brain._record_history()
	t.ok(brain._incoming_arm(arena, target).is_empty(), "reappearance does not infer rotation across an unseen interval")
	arm.rotation.y = 0.4
	brain._time = 2.4
	brain._record_history()
	t.ok(not brain._incoming_arm(arena, target).is_empty(), "second consecutive visible sample restores motion perception")


func _test_history_capacity(t: TestHarness, brain, arena: Arena, arm: ArenaHazards.Sweeper) -> void:
	brain.on_round_start()
	brain.reaction_time = 0.1
	brain.prediction = 0.0
	for i in range(AIBrain.HISTORY_CAP + 8):
		brain._time = i * AIBrain.HISTORY_SAMPLE_INTERVAL
		arm.rotation.y = brain._time
		brain._record_history()
	t.equal(brain._history_sweepers.size(), AIBrain.HISTORY_CAP, "arm history remains bounded")
	brain._time += brain.reaction_time + 0.00001
	var target := Vector3.RIGHT.rotated(Vector3.UP, arm.rotation.y + 0.4) * 3.0
	var threat: Dictionary = brain._incoming_arm(arena, target)
	t.ok(not threat.is_empty(), "wrapped history retains newest visible trajectory")
	if not threat.is_empty():
		t.near(float(threat["eta"]), 0.4, 0.001, "ring overwrite preserves sample timing")
	brain._lead = 0.4
	brain._dodge_until = 0.5
	brain.on_round_start()
	t.equal(brain._history_sweepers.size(), 0, "restart clears bounded hazard history")
	t.near(brain._dodge_until, 0.0, 0.00001, "restart clears encounter cooldown")
	t.near(brain._lead, -1.0, 0.00001, "restart clears encounter jump timing")


func _test_prediction(t: TestHarness, brain, arena: Arena, arm: ArenaHazards.Sweeper) -> void:
	brain.on_round_start()
	brain.reaction_time = 0.5
	brain.edge_awareness = 1.0
	for direction in [-1.0, 1.0]:
		brain.on_round_start()
		brain._time = 1.0
		arm.rotation.y = 0.0
		brain._record_history()
		brain._time = 1.1
		arm.rotation.y = direction * 0.1
		brain._record_history()
		brain._time = 1.6
		var target := Vector3.RIGHT.rotated(Vector3.UP, direction * 0.7) * 3.0
		for strength in [0.0, 0.5, 1.0, 2.0, -1.0]:
			brain.prediction = strength
			var threat: Dictionary = brain._incoming_arm(arena, target)
			t.ok(not threat.is_empty(), "bounded prediction retains the incoming observed threat")
			if not threat.is_empty():
				var expected := 0.6 - 0.5 * clampf(strength, 0.0, 1.0)
				t.near(float(threat["eta"]), expected, 0.001, "prediction estimates present angle from delayed visible angular motion")
		brain.prediction = 1.0
		arm.rotation.y = -direction * 2.0
		arm.speed = -direction * 50.0
		var predicted: Dictionary = brain._incoming_arm(arena, target)
		t.near(float(predicted.get("eta", -1.0)), 0.1, 0.001, "unsampled reversal cannot change the estimated trajectory")
		brain._time = 3.0
		predicted = brain._incoming_arm(arena, target)
		t.near(float(predicted.get("eta", -1.0)), 0.05, 0.001, "stale observation extrapolation is capped at reaction plus one sample interval")
