extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("Oasis cardinal approach parity")
	var config := MatchConfig.build("tank_arena", ["nabta", "sakhra", "fanoos", "ramla"], 0, 3, 510171)
	config.arena_id = "tank_oasis"
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": config})
	scene.set_physics_process(false)
	for fighter in scene.ctx.fighters:
		fighter.set_physics_process(false)
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	var world: Node3D = scene.controller.world
	var expected: float = scene.arena.def.radius * 0.62
	var center_height: float = world.ground_height(0.0, 0.0)
	for slot in 4:
		var start: Vector3 = scene.arena.spawn_points[slot]
		var route: PackedVector3Array = world.route(start, Vector3.ZERO)
		var length := 0.0
		for index in range(1, route.size()):
			length += route[index].distance_to(route[index - 1])
		t.ok(not route.is_empty(), "slot %d has an authored central route" % slot)
		if not route.is_empty():
			t.near(route[0].x, start.x, 0.01, "route begins at the actual spawn x")
			t.near(route[0].z, start.z, 0.01, "route begins at the actual spawn z")
			t.ok(route[-1].is_equal_approx(Vector3.ZERO), "route reaches central junction")
		print("OASIS_APPROACH slot=%d length=%.6f expected=%.6f" % [slot, length, expected])
		t.near(length, expected, 0.01, "slot %d has the same direct approach budget" % slot)
		var highest := center_height
		for sample in 21:
			var position := start.lerp(Vector3.ZERO, sample / 20.0)
			var height: float = world.ground_height(position.x, position.z)
			highest = maxf(highest, height)
			t.near(height, center_height, 0.05, "slot %d approach has no unpainted hill at sample %d" % [slot, sample])
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(start.x, center_height + 1.0, start.z),
			Vector3(0, center_height + 1.0, 0), 1)
		query.hit_from_inside = true
		var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
		print("OASIS_APPROACH slot=%d max_height=%.6f blocked=%s" % [slot, highest, not hit.is_empty()])
		t.ok(hit.is_empty(), "slot %d central approach has projectile-height clearance" % slot)
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
