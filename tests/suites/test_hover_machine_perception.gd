extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("rendered hover machine perception")
	for difficulty in 4:
		t.test("tier %d rendered warning, drop and mark" % difficulty)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("ring_rumble", ["fanoos", "nabta", "ramla", "sakhra"], 0, difficulty, 921), "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		for body in scene.ctx.fighters:
			body.set_physics_process(false)
		scene.ctx.observation_camera = null
		var machine: Node3D = scene.ctx.machine
		t.not_null(machine, "real arena has a hover machine")
		var me: Fighter = scene.ctx.fighter(0)
		me.global_position = Vector3(2, 0.8, 1)
		for i in [1, 2, 3]:
			scene.ctx.fighter(i).global_position = Vector3(-4 - i, 0.8, -2)
		var brain := AIBrain.new()
		brain.configure(0, scene.ctx, difficulty, 921)
		brain.accuracy = 1.0
		brain._time = 10.0
		machine._target_slot = 0
		machine._state = machine.State.TELEGRAPH
		machine._action = machine.Action.MARK
		machine._target_point = me.global_position
		machine._show_telegraph()
		machine._animate(0.0)
		t.ok(not brain.machine_threatens_me(), "first warning cannot bypass reaction delay")
		brain._time += brain.reaction_time - 0.0001
		t.ok(not brain.machine_threatens_me(), "warning is unavailable just before deadline")
		brain._time += 0.0001
		t.ok(brain.machine_threatens_me(), "visible red warning is actionable at deadline")
		machine._target_slot = 3
		machine._pending_id = "not_a_rendered_item"
		t.ok(brain.machine_threatens_me(), "hidden target and item state do not replace the drawn warning")
		machine._ground_ring.hide()
		t.ok(not brain.machine_threatens_me(), "hidden floor warning clears known threat")
		machine._ground_ring.show()
		t.ok(not brain.machine_threatens_me(), "reappearing warning must be reacquired")
		brain._time += brain.reaction_time
		t.ok(brain.machine_threatens_me(), "reappearing visible threat matures")
		machine._eye.hide()
		t.ok(not brain.machine_threatens_me(), "hidden severity colour cannot identify a penalty")
		machine._eye.show()

		machine._action = machine.Action.DROP
		machine._target_slot = -1
		machine._target_point = Vector3(3, 0.4, -2)
		machine._show_telegraph()
		machine._animate(0.0)
		var drawn_point: Vector3 = machine._ground_ring.global_position - Vector3(0, 0.16, 0)
		t.equal(brain.machine_drop_point(), Vector3.ZERO, "new visible crate preview starts a new delay")
		brain._time += brain.reaction_time
		t.equal(brain.machine_drop_point(), drawn_point, "mature crate preview exposes rendered location")
		machine._target_point = Vector3(100, 0, 100)
		t.equal(brain.machine_drop_point(), drawn_point, "private unrendered coordinates are not read")
		machine._target_point = Vector3(4, 0.4, -3)
		machine._aim_beam()
		brain._time += 0.01
		t.equal(brain.machine_drop_point(), drawn_point, "moving rendered preview remains reaction-delayed")
		brain._time += brain.reaction_time
		t.near(brain.machine_drop_point().distance_to(machine._target_point), 0.0, 0.00001, "updated rendered preview matures")
		for sample in 96:
			brain._time += 0.05
			brain.machine_drop_point()
		t.equal(brain._machine_cue_history.warning.size(), AIBrain.HISTORY_CAP, "cue history is bounded")
		machine._drop_preview.hide()
		t.equal(brain.machine_drop_point(), Vector3.ZERO, "hidden crate preview immediately invalidates drop")

		machine._set_mark(1)
		machine._tick_mark(0.0)
		t.equal(brain.marked_slot(), -1, "new visible mark requires reaction delay")
		brain._time += brain.reaction_time
		t.equal(brain.marked_slot(), 1, "mature marker is associated with its visible carrier")
		scene.ctx.fighter(1).hide()
		t.equal(brain.marked_slot(), -1, "marker cannot leak a hidden carrier identity")
		scene.ctx.fighter(1).show()
		t.equal(brain.marked_slot(), -1, "visible carrier must be reacquired")
		brain._time += brain.reaction_time
		t.equal(brain.marked_slot(), 1, "carrier reacquisition matures")
		brain.on_round_start()
		t.equal(brain.marked_slot(), -1, "round restart forgets marker history")
		machine.reset()
		t.equal(brain.machine_drop_point(), Vector3.ZERO, "machine reset hides crate preview")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
