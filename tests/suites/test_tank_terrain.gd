extends RefCounted

const Preparation = preload("res://src/match/match_resource_preparation.gd")
const CoverHulls = preload("res://src/arenas/cover_hull_cache.gd")


func _subset_hull(original: ConvexPolygonShape3D, world_scale: float, budget: int) -> ConvexPolygonShape3D:
	var directions: Array[Vector3] = []
	var supports: Array[float] = []
	var indices: Array[int] = []
	var retained := PackedVector3Array()
	for latitude in range(-16, 17):
		for longitude in 64:
			var phi := PI * float(latitude) / 32.0
			var theta := TAU * float(longitude) / 64.0
			var direction := Vector3(cos(phi) * cos(theta), sin(phi), cos(phi) * sin(theta))
			var support := -INF
			var index := 0
			for i in original.points.size():
				var value := original.points[i].dot(direction)
				if value > support:
					support = value
					index = i
			directions.append(direction)
			supports.append(support)
			indices.append(index)
	var candidate_supports: Array[float] = []
	candidate_supports.resize(directions.size())
	candidate_supports.fill(-INF)
	while retained.size() < budget:
		var worst := -INF
		var worst_index := 0
		for i in directions.size():
			var deficit := supports[i] - candidate_supports[i]
			if deficit > worst:
				worst = deficit
				worst_index = i
		if retained.size() >= 4 and worst * world_scale <= 0.01:
			break
		var point := original.points[indices[worst_index]]
		if retained.has(point):
			break
		retained.append(point)
		for i in directions.size():
			candidate_supports[i] = maxf(candidate_supports[i], point.dot(directions[i]))
	var shape := ConvexPolygonShape3D.new()
	shape.points = retained
	return shape


func run(t: TestHarness, host: Node) -> void:
	t.suite("tank terrain collision ownership")
	var changed_mesh := BoxMesh.new()
	t.ok(CoverHulls.resolve(changed_mesh, 0).points == changed_mesh.create_convex_shape().points,
		"changed source digest falls back to original geometry")
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
			if OS.get_cmdline_user_args().has("--cover-hull-probe") and not cover_shapes.has(visual.mesh):
				var simplified: ConvexPolygonShape3D = visual.mesh.create_convex_shape(true, true)
				for argument in OS.get_cmdline_user_args():
					if argument.begins_with("--cover-hull-vertices="):
						var settings := MeshConvexDecompositionSettings.new()
						settings.max_num_vertices_per_convex_hull = argument.trim_prefix("--cover-hull-vertices=").to_int()
						settings.resolution = 1000000
						settings.convex_hull_approximation = false
						var proxy := MeshInstance3D.new()
						proxy.mesh = visual.mesh
						proxy.create_multiple_convex_collisions(settings)
						t.equal(proxy.get_child_count(), 1, "hull probe produces one collision body")
						if proxy.get_child_count() == 1 and proxy.get_child(0).get_child_count() == 1:
							simplified = proxy.get_child(0).get_child(0).shape
						else:
							t.ok(false, "hull probe must retain one convex shape")
						proxy.free()
				var original: ConvexPolygonShape3D = visual.mesh.create_convex_shape()
				for argument in OS.get_cmdline_user_args():
					if argument.begins_with("--cover-subset-vertices="):
						var max_scale := 8.2 / maxf(visual.mesh.get_aabb().size.x, visual.mesh.get_aabb().size.z)
						simplified = _subset_hull(original, max_scale, argument.trim_prefix("--cover-subset-vertices=").to_int())
						var probe_body := StaticBody3D.new()
						probe_body.collision_layer = 1 << 19
						probe_body.collision_mask = 0
						var probe_shape := CollisionShape3D.new()
						probe_shape.shape = simplified
						probe_shape.scale = Vector3.ONE * max_scale
						probe_body.add_child(probe_shape)
						world.add_child(probe_body)
						probe_body.global_position = Vector3(1000, 0, 1000)
						await host.get_tree().physics_frame
						await host.get_tree().physics_frame
						var sphere := SphereShape3D.new()
						sphere.radius = 0.05
						var query := PhysicsShapeQueryParameters3D.new()
						query.shape = sphere
						query.collision_mask = probe_body.collision_layer
						var misses := 0
						for repair in 4:
							misses = 0
							var missing := PackedVector3Array()
							for point in original.points:
								query.transform = Transform3D(Basis.IDENTITY, probe_body.global_position + point * max_scale)
								if world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
									misses += 1
									missing.append(point)
							if misses == 0 or repair == 3:
								break
							var repaired := simplified.points
							for point in missing:
								if not repaired.has(point):
									repaired.append(point)
							simplified.points = repaired
							await host.get_tree().physics_frame
							await host.get_tree().physics_frame
						print("COVER_SUBSET_CLEARANCE ", arena_id, " cover=", cover.name, " vertices_outside_5cm=", misses)
						if misses > 0:
							probe_shape.shape = original
							await host.get_tree().physics_frame
							await host.get_tree().physics_frame
							var control_misses := 0
							for point in original.points:
								query.transform = Transform3D(Basis.IDENTITY, probe_body.global_position + point * max_scale)
								if world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
									control_misses += 1
							print("COVER_ORIGINAL_CLEARANCE ", arena_id, " cover=", cover.name, " vertices_outside_5cm=", control_misses)
						t.equal(misses, 0, "every original hull vertex remains within 5cm of candidate")
						for point in simplified.points:
							t.ok(original.points.has(point), "subset hull never introduces an external vertex")
						if misses == 0 and OS.get_cmdline_user_args().has("--bake-cover-hulls"):
							DirAccess.make_dir_recursive_absolute("res://data/collision")
							simplified.set_meta("source_digest", CoverHulls.mesh_digest(visual.mesh))
							simplified.set_meta("max_world_width", 8.2)
							var mesh_index: int = world._rock_meshes.find(visual.mesh)
							t.equal(ResourceSaver.save(simplified, "res://data/collision/rock_cover_%d.tres" % mesh_index), OK, "validated hull saved")
						probe_body.free()
				var max_error := 0.0
				var min_error := 0.0
				for latitude in range(-8, 9):
					for longitude in 32:
						var phi := PI * float(latitude) / 16.0
						var theta := TAU * float(longitude) / 32.0
						var direction := Vector3(cos(phi) * cos(theta), sin(phi), cos(phi) * sin(theta))
						var a := -INF
						var b := -INF
						for point in original.points:
							a = maxf(a, point.dot(direction))
						for point in simplified.points:
							b = maxf(b, point.dot(direction))
						var error := (b - a) * collider.scale.x
						max_error = maxf(max_error, error)
						min_error = minf(min_error, error)
				print("COVER_HULL_PROBE ", arena_id, " cover=", cover.name,
					" original=", original.points.size(), " simplified=", simplified.points.size(),
					" support_error_world_m=", [min_error, max_error])
			t.ok(collider.shape is ConvexPolygonShape3D, "rock retains convex collision: " + arena_id)
			if cover_shapes.has(visual.mesh):
				t.equal(collider.shape, cover_shapes[visual.mesh], "repeated rock mesh shares its immutable hull: " + arena_id)
			else:
				t.ok(not cover_shapes.values().has(collider.shape), "different rock meshes retain distinct hulls: " + arena_id)
				cover_shapes[visual.mesh] = collider.shape
				var authored := visual.mesh.create_convex_shape()
				if OS.get_cmdline_user_args().has("--original-cover-hulls"):
					t.ok(collider.shape.points == authored.points, "control retains the original collision hull")
				else:
					t.equal(collider.shape.get_meta("source_digest", ""), CoverHulls.mesh_digest(visual.mesh), "baked hull matches exact source vertices")
					t.ok(collider.shape.points.size() <= 200, "baked hull stays within the verified vertex budget")
					for point in collider.shape.points:
						t.ok(authored.points.has(point), "baked hull remains a subset of original vertices")
					t.ok(CoverHulls.resolve(visual.mesh, 99).points == authored.points, "missing cache retains original hull")
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
		if arena_id == "tank_oasis":
			var recipe := load("res://src/arenas/woodland_valley_layout.gd")
			var points: PackedVector3Array = recipe.points()
			var connections := 0
			for id in points.size():
				t.ok(world.roads.get_point_position(id).is_equal_approx(points[id]), "forest junction follows winding meadow recipe")
				t.ok(not world.route(points[id], Vector3.ZERO).is_empty(), "all meadow routes reach the central crossing")
				for neighbour in world.roads.get_point_connections(id):
					connections += 1
					if neighbour < id:
						continue
					for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
						var p: Vector3 = points[id].lerp(points[neighbour], fraction)
						t.near(world.ground_height(p.x, p.z), 0.02, 0.001, "forest route stays driveable along the whole segment")
			t.equal(connections, 60, "paired meadows have 30 bidirectional connections, not the old grid")
			for direction in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
				var spawn: Vector3 = direction * 28.52
				t.near(world.ground_height(spawn.x, spawn.z), 0.02, 0.001, "forest cardinal spawn stays on a clear level route")
			var road_shader: ShaderMaterial = terrain.material_override
			t.equal(road_shader.get_shader_parameter("authored_road_mask"), true, "forest rendered roads follow the navigation recipe")
			t.ok(not points == load("res://src/arenas/rocky_pass_layout.gd").points(), "forest geography differs from rocky loops")
		if arena_id == "tank_foundry":
			t.ok(world.roads.get_point_position(24).is_equal_approx(Vector3.ZERO), "rocky pass has a central junction, not another grid corner")
			for id in 24:
				var point: Vector3 = world.roads.get_point_position(id)
				t.near(Vector2(point.x, point.z).length(), 36.0 if id < 16 else 18.0, 0.001, "rocky pass authored ring radius")
			var road_shader: ShaderMaterial = world.get_node("WoodlandTerrain").material_override
			t.equal(road_shader.get_shader_parameter("authored_road_mask"), true, "road appearance follows the authored network")
			var connections := 0
			for id in 25:
				t.ok(not world.route(world.roads.get_point_position(id), Vector3.ZERO).is_empty(), "every authored junction reaches the centre")
				for neighbour in world.roads.get_point_connections(id):
					connections += 1
					if neighbour < id:
						continue
					for fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
						var p: Vector3 = world.roads.get_point_position(id).lerp(world.roads.get_point_position(neighbour), fraction)
						t.near(world.ground_height(p.x, p.z), 0.02, 0.001, "all authored route segments retain level driveable ground")
			t.equal(connections, 72, "two rings and radial shortcuts form 36 bidirectional edges")
			for direction in [Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
				var p: Vector3 = direction * 28.52
				t.near(world.ground_height(p.x, p.z), 0.02, 0.001, "all four natural spawns have equal clear approach height")
			t.ok(world.ground_height(7.0, 7.0) > 2.0, "terrain between the routes rises into a rocky pass rather than a flat grid")
		t.ok(not world.route(world.roads.get_point_position(0), world.roads.get_point_position(24)).is_empty(),
			"opposite corners remain connected: " + arena_id)
		await host.get_tree().physics_frame
		await host.get_tree().physics_frame
		for cover: StaticBody3D in world.buildings:
			var visual: MeshInstance3D = cover.get_child(0)
			var original := visual.mesh.create_convex_shape()
			var sphere := SphereShape3D.new()
			sphere.radius = 0.05
			var vertex_query := PhysicsShapeQueryParameters3D.new()
			vertex_query.shape = sphere
			vertex_query.collision_mask = cover.collision_layer
			var misses := 0
			for point in original.points:
				vertex_query.transform = Transform3D(Basis.IDENTITY, visual.to_global(point))
				var hits := world.get_world_3d().direct_space_state.intersect_shape(vertex_query, 32)
				var found := false
				for contact in hits:
					if contact.collider == cover:
						found = true
						break
				if not found:
					misses += 1
			t.equal(misses, 0, "actual rotated cover retains 5cm physical boundary coverage: " + str(cover.name))
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
			if OS.get_cmdline_user_args().has("--terrain-debug") and frame % 30 == 29:
				var contacts := []
				for index in driver.get_slide_collision_count():
					var collision := driver.get_slide_collision(index)
					contacts.append({"node": collision.get_collider().name, "normal": collision.get_normal()})
				print("TERRAIN_TRAVERSAL ", arena_id, " frame=", frame, " position=", driver.position, " contacts=", contacts)
		t.ok(driver.global_position.x > 3.5, "actual driver crosses the terrain origin without sticking: " + arena_id)
		t.ok(driver.is_on_floor(), "driver retains ground contact during real traversal: " + arena_id)
		t.ok(driver.global_position.y >= world.ground_height(driver.global_position.x, driver.global_position.z) - 0.1,
			"real traversal does not drop the driver through the surface: " + arena_id)
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
