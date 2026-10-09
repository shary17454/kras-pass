extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("climber same-ledge contest perception")
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": MatchConfig.build("rising_tide", ["fanoos", "nabta", "ramla", "sakhra"], 0, 3, 813)})
	scene.set_physics_process(false)
	scene.ctx.observation_camera = null
	for fighter in scene.ctx.fighters:
		fighter.set_physics_process(false)
	var brain = load("res://src/ai/brains/climber_brain.gd").new()
	brain.configure(0, scene.ctx, 3, 813)
	t.ok(brain.has_method("_same_ledge_rival"), "climber can contest observed rivals on its current ledge")
	if brain.has_method("_same_ledge_rival"):
		for difficulty in 4:
			brain.configure(0, scene.ctx, difficulty, 813)
			brain.on_round_start()
			scene.ctx.fighter(0).global_position = Vector3(0, 100, 0)
			scene.ctx.fighter(1).global_position = Vector3(3, 100, 0)
			scene.ctx.fighter(2).global_position = Vector3(2, 100, 0)
			scene.ctx.fighter(3).global_position = Vector3(1, 102, 0)
			brain._time = 10.0
			brain._record_history()
			t.equal(brain.call("_same_ledge_rival"), -1, "new rival waits for reaction at tier %d" % difficulty)
			brain._time += brain.reaction_time
			brain._record_history()
			t.equal(brain.call("_same_ledge_rival"), 2, "nearest delayed same-level rival beats slot order and elevated rival")
			scene.ctx.fighter(2).hide()
			t.equal(brain.call("_same_ledge_rival"), 1, "hidden rival cannot be contested")
			scene.ctx.fighter(1).hide()
			t.equal(brain.call("_same_ledge_rival"), -1, "rival on a higher tier is not a same-ledge target")
			scene.ctx.fighter(1).show()
			scene.ctx.fighter(2).show()
			brain.on_round_start()
			t.equal(brain.call("_same_ledge_rival"), -1, "new round clears rival acquisition")
		await _summit_decision(t, host, scene, brain)
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame


func _summit_decision(t: TestHarness, host: Node, scene: Node, brain) -> void:
	var summit: Node3D = scene.arena.get_node("Static/Summit")
	var body: Fighter = scene.ctx.fighter(0)
	for slot in [2, 3]:
		scene.ctx.fighter(slot).hide()
	body.respawn_at(summit.global_position + Vector3(0, 1, 0))
	body.control_enabled = true
	scene.ctx.fighter(1).global_position = summit.global_position + Vector3(2.5, 0.5, 0)
	for tick in 40:
		await host.get_tree().physics_frame
		body.tick(InputFrame.new(), 1.0 / 60.0)
	t.ok(body.is_on_floor(), "contest decision starts on actual summit collision")
	scene.ctx.fighter(1).global_position.y = body.global_position.y
	brain.configure(0, scene.ctx, 3, 813)
	brain.on_round_start()
	brain.aggression = 2.0
	brain._time = 10.0
	brain._record_history()
	brain._time += brain.reaction_time
	brain._record_history()
	brain._ledge_target = body.global_position
	brain.decide(1.0 / 60.0)
	t.ok(brain.move.x > 0.5, "at summit the actual decision approaches the observed rival")
	var higher := body.global_position + Vector3(0, 1.0, 3.5)
	brain._ledge_target = higher
	brain._prepare_jump = true
	brain.move = Vector2.ZERO
	brain.decide(1.0 / 60.0)
	t.equal(brain._ledge_target, higher, "contest does not replace an existing higher route")
	t.ok(not brain._prepare_jump, "higher route runs the jump preparation lifecycle rather than contest early return")
