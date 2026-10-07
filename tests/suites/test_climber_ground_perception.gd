extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("climber delayed ground knowledge")
	for difficulty in 4:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("rising_tide", ["fanoos", "nabta", "ramla", "sakhra"], 0, difficulty, 805)})
		scene.set_physics_process(false)
		for fighter in scene.ctx.fighters:
			fighter.set_physics_process(false)
		# This fixture isolates the timing contract; camera/ray behavior has
		# separate actual-world visibility coverage.
		scene.ctx.observation_camera = null
		for slot in range(1, 4):
			scene.ctx.fighter(slot).hide()
		var from := Vector3(0, 100, 0)
		scene.ctx.fighter(0).global_position = from
		var ground := _ground()
		scene.arena.get_node("Static").add_child(ground)
		var p0 := Vector3(1, 100.6, 0)
		var p1 := Vector3(2, 100.7, 0)
		var p2 := Vector3(3, 100.8, 0)
		ground.global_position = p0
		var brain = load("res://src/ai/brains/climber_brain.gd").new()
		brain.configure(0, scene.ctx, difficulty, 805)
		brain.aggression = 0.0
		brain.on_round_start()
		brain._time = 10.0
		t.equal(brain._find_higher_ground(from), from, "tier %d first ground observation waits for reaction" % difficulty)
		brain._time = 10.0 + brain.reaction_time - 0.0001
		t.equal(brain._find_higher_ground(from), from, "tier %d ground reaction does not expire early" % difficulty)
		brain._time = 10.0 + brain.reaction_time
		ground.global_position = p1
		t.equal(brain._find_higher_ground(from), p0 + Vector3.UP * 0.25, "tier %d ground choice uses delayed observed position" % difficulty)
		brain._time += brain.reaction_time
		ground.global_position = p2
		var known: Vector3 = brain._find_higher_ground(from)
		t.equal(known, p1 + Vector3.UP * 0.25, "tier %d subsequent visible movement remains delayed" % difficulty)
		brain._ledge_target = known
		ground.hide()
		ground.global_position = Vector3(40, 200, 0)
		brain.decide(0.01)
		t.equal(brain._ledge_target, known, "tier %d remembers an observed route without reading hidden movement" % difficulty)
		t.equal(brain._find_higher_ground(from), from, "tier %d cannot adopt currently hidden new ground" % difficulty)
		ground.show()
		ground.global_position = p0
		brain.on_round_start()
		t.equal(brain._ledge_target, Vector3.INF, "tier %d new round clears prior ledge target" % difficulty)
		t.equal(brain._find_higher_ground(from), from, "tier %d new round earns no old observation credit" % difficulty)
		brain._time += brain.reaction_time
		t.equal(brain._find_higher_ground(from), p0 + Vector3.UP * 0.25, "tier %d ground is usable after new-round delay" % difficulty)
		brain._ledge_target = p0 + Vector3.UP
		brain.configure(0, scene.ctx, difficulty, 806)
		t.equal(brain._ledge_target, Vector3.INF, "tier %d reconfiguration clears prior ground plan" % difficulty)
		t.equal(brain._find_higher_ground(from), from, "tier %d reconfiguration clears prior observation credit" % difficulty)
		brain._time += brain.reaction_time
		t.equal(brain._find_higher_ground(from), p0 + Vector3.UP * 0.25, "prior ground becomes observed before replacement")
		ground.free()
		ground = _ground()
		scene.arena.get_node("Static").add_child(ground)
		ground.global_position = p0
		t.equal(brain._find_higher_ground(from), from, "tier %d replacement instance earns no previous observation credit" % difficulty)
		brain.reaction_time = 0.0
		t.equal(brain._find_higher_ground(from), p0 + Vector3.UP * 0.25, "zero-delay diagnostic contract remains immediate")
		scene.ctx.observation_camera = scene.camera
		var original_view: Transform3D = scene.camera.global_transform
		scene.camera.global_position += Vector3.UP * 100.0
		t.ok(brain.can_observe(ground), "actual camera can see the rendered ground fixture")
		t.equal(brain._find_higher_ground(from), p0 + Vector3.UP * 0.25, "actual visible geometry remains actionable")
		var transparent := StandardMaterial3D.new()
		transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		transparent.albedo_color = Color(1, 1, 1, 0)
		ground.get_child(0).material_override = transparent
		t.equal(brain._find_higher_ground(from), from, "fully transparent ground is not new navigable knowledge")
		ground.get_child(0).material_override = null
		scene.camera.global_transform = original_view
		t.equal(brain._find_higher_ground(from), from, "off-screen geometry cannot enter a new ground plan")
		scene.ctx.observation_camera = null
		for sample in 100:
			brain._time += 0.01
			brain._find_higher_ground(from)
		var history = brain.get("_ground_history")
		t.ok(history is Dictionary, "ground observations have a bounded history")
		if history is Dictionary:
			t.ok(history[ground.get_instance_id()].size() <= brain.HISTORY_CAP, "ground history cannot grow without bound")
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame


func _ground() -> StaticBody3D:
	var body := StaticBody3D.new()
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1, 0.5, 1)
	mesh.mesh = box
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = box.size
	collision.shape = shape
	body.add_child(collision)
	return body
