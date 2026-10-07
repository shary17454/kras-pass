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
		var cover_shapes := {}
		for cover: StaticBody3D in world.buildings:
			var visual: MeshInstance3D = cover.get_child(0)
			var collider: CollisionShape3D = cover.get_child(1)
			t.ok(collider.shape is ConvexPolygonShape3D, "rock retains convex collision: " + arena_id)
			if cover_shapes.has(visual.mesh):
				t.equal(collider.shape, cover_shapes[visual.mesh], "repeated rock mesh shares its immutable hull: " + arena_id)
			else:
				t.ok(not cover_shapes.values().has(collider.shape), "different rock meshes retain distinct hulls: " + arena_id)
				cover_shapes[visual.mesh] = collider.shape
				t.ok(collider.shape.points == visual.mesh.create_convex_shape().points, "shared hull preserves generated collision geometry: " + arena_id)
			t.equal(collider.position, visual.position, "shared hull retains cover offset: " + arena_id)
			t.equal(collider.scale, visual.scale, "shared hull retains cover scale: " + arena_id)
		t.equal(world.buildings.size(), 16, "all authored rock obstacles remain: " + arena_id)
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
		var driver: Fighter = scene.ctx.fighter(0)
		driver.global_position = Vector3(-2, 1.5, 0)
		for frame in 120:
			await host.get_tree().physics_frame
			driver.velocity = Vector3(3, -3, 0)
			driver.move_and_slide()
		t.ok(driver.global_position.x > 3.5, "actual driver crosses the terrain origin without sticking: " + arena_id)
		t.ok(driver.is_on_floor(), "driver retains ground contact during real traversal: " + arena_id)
		t.ok(driver.global_position.y >= world.ground_height(driver.global_position.x, driver.global_position.z) - 0.1,
			"real traversal does not drop the driver through the surface: " + arena_id)
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
