extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("siege rendered base perception")
	for difficulty in 4:
		t.test("tier %d visible crystal and delayed HUD health" % difficulty)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("base_siege", ["fanoos", "nabta", "ramla", "sakhra"], 0, difficulty, 871), "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		for body in scene.ctx.fighters:
			body.set_physics_process(false)
		scene.ctx.observation_camera = null
		var controller: Node = scene.controller
		controller._bases[1].health = 1.1
		controller._bases[2].health = 50.1
		controller._bases[3].health = 0.0
		var brain = load("res://src/ai/brains/siege_brain.gd").new()
		brain.configure(0, scene.ctx, difficulty, 871)
		brain.controller = controller
		brain._time = 10.0
		t.equal(brain._weakest_rival_base(), -1, "first visible base needs reaction delay")
		brain._time += brain.reaction_time - 0.0001
		t.equal(brain._weakest_rival_base(), -1, "base knowledge is unavailable before deadline")
		brain._time += 0.0001
		t.equal(brain._weakest_rival_base(), 1, "visible weak crystal is selected at deadline")
		controller._bases[1].health = 99.1
		brain._time += 0.01
		t.equal(brain._weakest_rival_base(), 1, "new public health is not read before delay")
		brain._time += brain.reaction_time
		t.equal(brain._weakest_rival_base(), 2, "changed public health matures")
		controller._bases[2].crystal.hide()
		t.equal(brain._weakest_rival_base(), 1, "hidden crystal is excluded despite visible plinth")
		controller._bases[1].crystal.hide()
		brain.move = Vector2.ONE
		for body in scene.ctx.fighters:
			body.hide()
		brain.decide(0.05)
		t.equal(brain.move, Vector2.ZERO, "no observed target cannot retain stale siege movement")
		controller._bases[1].crystal.show()
		t.equal(brain._weakest_rival_base(), -1, "reappearing crystal needs reacquisition")
		brain._time += brain.reaction_time
		t.equal(brain._weakest_rival_base(), 1, "reappearing crystal matures")
		var cue: Dictionary = brain._base_cue(1)
		t.equal(cue.health, 99, "observed health is the whole HUD percentage")
		var original: Vector3 = cue.position
		controller._bases[1].crystal.position.x += 2.0
		brain._time += 0.01
		t.equal(brain._base_cue(1).position, original, "new rendered position is delayed")
		brain._time += brain.reaction_time
		t.near(brain._base_cue(1).position.x, original.x + 2.0, 0.00001, "mature position follows the crystal, not its root")
		for sample in 96:
			brain._time += 0.05
			brain._base_cue(1)
		t.equal(brain._base_history[1].size(), AIBrain.HISTORY_CAP, "base history is bounded")
		var replacement := MeshInstance3D.new()
		replacement.mesh = BoxMesh.new()
		controller._bases[1].crystal.hide()
		controller._bases[1].node.add_child(replacement)
		controller._bases[1].crystal = replacement
		t.equal(brain._weakest_rival_base(), -1, "replacement crystal cannot inherit old knowledge")
		brain._time += brain.reaction_time
		t.equal(brain._weakest_rival_base(), 1, "replacement crystal matures normally")
		var camera := Camera3D.new()
		scene.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 6.0
		camera.global_position = Vector3(100, 25, 100)
		camera.look_at(Vector3(100, 0, 100), Vector3.FORWARD)
		scene.ctx.observation_camera = camera
		t.equal(brain._weakest_rival_base(), -1, "out-of-camera crystal is not an eligible target")
		scene.ctx.observation_camera = null
		brain.reaction_time = 0.0
		camera.global_position = Vector3(0, 25, 0)
		camera.size = 200.0
		camera.look_at(Vector3.ZERO, Vector3.FORWARD)
		scene.ctx.observation_camera = camera
		t.equal(brain._weakest_rival_base(), 1, "in-camera crystal is visible without cover")
		controller._bases[0].node.global_position = Vector3(0, 0, -4)
		controller._bases[2].node.global_position = Vector3(0, 0, 4)
		controller._bases[2].crystal.show()
		controller._bases[2].health = 1.0
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 100.0
		camera.global_position = Vector3(0, 1.35, -10)
		camera.look_at(Vector3(0, 1.35, 4), Vector3.UP)
		await host.get_tree().physics_frame
		await host.get_tree().physics_frame
		t.ok(brain.can_observe(controller._bases[0].crystal), "own collision proxy does not hide its visible crystal")
		t.ok(not brain.can_observe(controller._bases[2].crystal), "foreground base crystal is real cover for a rear crystal")
		controller._bases[2].crystal.hide()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 200.0
		camera.global_position = Vector3(0, 25, 0)
		camera.look_at(Vector3.ZERO, Vector3.FORWARD)
		var wall := StaticBody3D.new()
		wall.collision_layer = 1
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(100, 1, 100)
		collision.shape = shape
		wall.add_child(collision)
		var wall_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = shape.size
		wall_mesh.mesh = box
		wall.add_child(wall_mesh)
		scene.ctx.world_root.add_child(wall)
		wall.global_position = Vector3(0, 15, 0)
		await host.get_tree().physics_frame
		await host.get_tree().physics_frame
		t.equal(brain._weakest_rival_base(), -1, "actual opaque collision wall hides crystals")
		scene.ctx.observation_camera = null
		brain.reaction_time = 0.1
		brain.on_round_start()
		t.equal(brain._weakest_rival_base(), -1, "round reset clears base observations")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
