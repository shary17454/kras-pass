extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("AI empowerment observation delay")
	var root := Node3D.new()
	host.add_child(root)
	root.position.y = 1000.0
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 1, 10)
	camera.look_at(root.global_position + Vector3.UP, Vector3.UP)
	camera.set_perspective(90, 0.1, 50)
	var context := MatchContext.new()
	context.config = MatchConfig.new()
	context.observation_camera = camera
	context.alive.assign([true, true])
	for index in 2:
		var fighter := Fighter.new()
		fighter.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(fighter)
		fighter.position = Vector3(index * 2, 1, 0)
		context.fighters.append(fighter)
	var rival := context.fighter(1)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	root.add_child(wall)
	wall.position = Vector3(0, 1, 5)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(12, 8, 1)
	mesh.mesh = box
	wall.add_child(mesh)
	var shape := CollisionShape3D.new()
	var collision := BoxShape3D.new()
	collision.size = box.size
	shape.shape = collision
	wall.add_child(shape)
	mesh.hide()
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	for difficulty in 4:
		for modifier in ["push", "weight", "size", "shield"]:
			t.test("tier %d delayed %s activation and removal" % [difficulty, modifier])
			var brain := AIBrain.new()
			brain.configure(0, context, difficulty, 431)
			var baseline := float(rival.mods[modifier])
			_sample(brain, 10.0)
			var delay := brain.reaction_time
			_sample(brain, 11.0)
			t.ok(not brain.is_empowered(1), "baseline rival is not empowered")
			rival.mods[modifier] = 2.0
			_sample(brain, 12.0)
			t.ok(not brain.is_empowered(1), "activation does not leak at observation time")
			brain._time = 12.0 + delay - 0.0001
			t.ok(not brain.is_empowered(1), "activation stays unknown before deadline")
			brain._time = 12.0 + delay
			t.ok(brain.is_empowered(1), "activation becomes known at deadline")
			rival.mods[modifier] = baseline
			t.ok(brain.is_empowered(1), "unsampled removal cannot change remembered state")
			_sample(brain, 14.0)
			t.ok(brain.is_empowered(1), "removal does not leak at observation time")
			brain._time = 14.0 + delay - 0.0001
			t.ok(brain.is_empowered(1), "removal stays unknown before deadline")
			brain._time = 14.0 + delay
			t.ok(not brain.is_empowered(1), "removal becomes known at deadline")
			brain.on_round_start()
			rival.mods[modifier] = 2.0
			_sample(brain, 20.0)
			t.ok(not brain.is_empowered(1), "round restart requires a fresh observation delay")
			brain._time = 20.0 + delay
			t.ok(brain.is_empowered(1), "first empowered observation matures normally")
			for index in AIBrain.HISTORY_CAP + 4:
				_sample(brain, 22.0 + index * 0.05)
			t.ok(brain.is_empowered(1), "empowerment survives history ring wrap")
			rival.mods[modifier] = baseline
			_sample(brain, 26.0)
			t.ok(brain.is_empowered(1), "wrapped history delays removal too")
			brain._time = 26.0 + delay
			t.ok(not brain.is_empowered(1), "wrapped history exposes removal at deadline")
			rival.mods[modifier] = 2.0
			_sample(brain, 28.0)
			brain._time = 28.0 + delay
			t.ok(brain.is_empowered(1), "wrapped history accepts a subsequent activation")
			brain.on_round_start()
			t.ok(not brain.is_empowered(1), "cleared history exposes no previous-round strength")
			rival.mods[modifier] = baseline
	t.test("actual opaque occlusion and delayed reacquisition")
	var brain := AIBrain.new()
	brain.configure(0, context, 1, 431)
	brain.reaction_time = 0.5
	_sample(brain, 30.0)
	_sample(brain, 31.0)
	mesh.show()
	t.ok(not brain.can_observe(rival), "opaque wall actually occludes the rival")
	rival.mods["shield"] = 1.0
	_sample(brain, 32.0)
	brain._time = 33.0
	t.ok(not brain.is_empowered(1), "hidden activation cannot be inspected")
	mesh.hide()
	_sample(brain, 34.0)
	t.ok(brain.can_observe(rival), "hiding the wall restores visibility")
	t.ok(not brain.is_empowered(1), "reappearance does not expose hidden activation instantly")
	brain._time = 34.4999
	t.ok(not brain.is_empowered(1), "reacquisition waits for reaction deadline")
	brain._time = 34.5
	t.ok(brain.is_empowered(1), "reacquired activation matures at deadline")
	mesh.show()
	rival.mods["shield"] = 0.0
	_sample(brain, 35.0)
	brain._time = 36.0
	t.ok(not brain.is_empowered(1), "occluded rival is not reported empowered")
	mesh.hide()
	_sample(brain, 37.0)
	t.ok(not brain.is_empowered(1), "hidden removal does not bypass reacquisition")
	brain._time = 37.5
	t.ok(not brain.is_empowered(1), "visible removal matures without stale strength")
	var independent := AIBrain.new()
	independent.configure(0, context, 1, 432)
	rival.mods["shield"] = 1.0
	t.ok(not independent.is_empowered(1), "another brain cannot inherit observation history")
	brain.reaction_time = 0.0
	t.ok(brain.is_empowered(1), "explicit zero delay retains immediate visible strength")
	mesh.show()
	t.ok(not brain.is_empowered(1), "zero delay still respects actual occlusion")
	mesh.hide()
	context.fighter(0).mods["shield"] = 1.0
	brain.reaction_time = 0.5
	t.ok(brain.is_empowered(0), "own strength remains immediately known")
	t.ok(not brain.is_empowered(-1), "invalid negative slot fails closed")
	t.ok(not brain.is_empowered(2), "out-of-range slot fails closed")
	rival.mods["shield"] = 0.0
	root.queue_free()
	await host.get_tree().process_frame


func _sample(brain: AIBrain, at: float) -> void:
	brain._time = at
	brain._record_history()
