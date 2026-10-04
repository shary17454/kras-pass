extends RefCounted

const Preparation = preload("res://src/match/match_resource_preparation.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("tank terrain collision ownership")
	for arena_id in ["tank_foundry", "tank_oasis", "tank_frost"]:
		var cfg := MatchConfig.build("tank_arena", ["nabta", "sakhra", "barq", "turs"], 0, 2, 117)
		cfg.arena_id = arena_id
		var preparation := Preparation.new()
		host.add_child(preparation)
		t.ok(await preparation.prepare(Preparation.paths_for(cfg)), "tank world resources prepared: " + arena_id)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": cfg, "on_finished": func(_result): pass})
		scene.set_physics_process(false)
		preparation.release()
		var world: Node3D = scene.controller.world
		var terrain: MeshInstance3D = world.get_node("WoodlandTerrain")
		var bodies: Array[StaticBody3D] = []
		for child in world.get_children():
			if child is StaticBody3D and child.has_meta("observation_mesh") \
					and child.get_node_or_null(child.get_meta("observation_mesh")) == terrain:
				bodies.append(child)
		t.equal(bodies.size(), 1, "one authoritative terrain collider: " + arena_id)
		var body := bodies[0]
		var shape: CollisionShape3D = body.get_child(0)
		t.ok(shape.shape is ConcavePolygonShape3D, "terrain retains triangle collision: " + arena_id)
		t.ok(shape.shape.get_faces() == terrain.mesh.get_faces(), "collision preserves the rendered terrain triangles: " + arena_id)
		t.equal(body.get_node(body.get_meta("observation_mesh")), terrain, "AI observation resolves the same terrain mesh: " + arena_id)
		t.equal(world.roads.get_point_count(), 25, "road navigation graph remains intact: " + arena_id)
		t.ok(not world.route(world.roads.get_point_position(0), world.roads.get_point_position(24)).is_empty(),
			"opposite corners remain connected: " + arena_id)
		await host.get_tree().physics_frame
		await host.get_tree().physics_frame
		var query := PhysicsRayQueryParameters3D.create(Vector3(0, 10, 0), Vector3(0, -10, 0))
		query.collision_mask = body.collision_layer
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		t.ok(not hit.is_empty(), "the actual physics world still has driveable ground: " + arena_id)
		if not hit.is_empty():
			t.ok(hit.collider in bodies, "ray hits the single authored terrain body: " + arena_id)
			t.ok(absf(hit.position.y - world.ground_height(0, 0)) < 0.001,
				"physical ground height matches the authored surface: " + arena_id)
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
