extends RefCounted

func run(t: TestHarness, host: Node) -> void:
	t.suite("color call reaction clock")
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": MatchConfig.build("color_stand", ["fanoos", "mowja", "ramla", "nabta"], 0, 3, 901), "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	for body in scene.ctx.fighters: body.set_physics_process(false)
	for tile in scene.controller._tiles: tile.set_physics_process(false)
	var brain = load("res://src/ai/brains/color_brain.gd").new()
	brain.configure(0, scene.ctx, 3, 77)
	brain.controller = scene.controller
	brain.reaction_time = 0.12
	brain.decision_interval = 0.22
	brain.rng.seed = 19
	var expected_rng := RandomNumberGenerator.new()
	expected_rng.seed = 19
	var delay: float = brain.reaction_time * expected_rng.randf_range(0.8, 1.6)
	brain._time = 10.0
	brain.decide(0.001)
	t.ok(brain._committed == null, "first decision cannot subtract an entire decision interval from reaction time")
	for index in 20: brain.decide(0.001)
	t.ok(brain._committed == null, "repeated decisions without simulation time cannot expire the delay")
	brain._time = 10.0 + delay - 0.0001
	brain.decide(0.001)
	t.ok(brain._committed == null, "color remains uncommitted before sampled reaction deadline")
	brain._time = 10.0 + delay + 0.0001
	brain.decide(0.001)
	t.ok(is_instance_valid(brain._committed), "visible call becomes actionable after reaction deadline")
	if is_instance_valid(brain._committed):
		t.equal(brain._committed.tag, scene.controller.called_tag(), "chosen tile matches the announced color")
	var called: int = scene.controller._called
	var previous = brain._committed
	scene.controller._begin_call()
	scene.controller._called = called
	if is_instance_valid(previous): previous.tag = "stale_previous_layout"
	brain.decide(0.001)
	t.ok(brain._committed == null, "repeated-color new call invalidates the old tile and starts a fresh delay")
	brain._time += 1.0
	brain.decide(0.001)
	t.ok(is_instance_valid(brain._committed), "repeated-color call becomes actionable after its own delay")
	if is_instance_valid(brain._committed):
		t.equal(brain._committed.tag, scene.controller.called_tag(), "repeated color uses the current layout, not a stale standable tile")
	brain.on_round_start()
	t.ok(brain._committed == null, "round restart clears prior tile commitment")
	brain.decide(0.001)
	t.ok(brain._committed == null, "round restart does not carry prior reaction credit")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
