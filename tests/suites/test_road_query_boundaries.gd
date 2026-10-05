extends RefCounted


func run(t: TestHarness) -> void:
	t.suite("road query conservative bounds")
	var arena := Arena.new()
	var world: Node3D = load("res://src/arenas/natural_valley.gd").new()
	var legacy: Node3D = load("res://tests/fixtures/road_query_legacy.gd").new()
	world.arena = arena
	legacy.arena = arena
	var routes: Script = load("res://src/arenas/racing_routes.gd")
	for id in Registry.minigame("sabaq_sawarikh").arena_ids:
		arena.circuit_line = routes.points(id)
		for p in arena.circuit_line:
			for offset in [Vector2(-0.0001, -0.0001), Vector2(0.0001, 0.0001),
				Vector2(-0.0001, 0.0001), Vector2(0.0001, -0.0001)]:
				t.equal(world._nearest(p.x + offset.x, p.z + offset.y),
					legacy._nearest(p.x + offset.x, p.z + offset.y),
					"%s near-endpoint query preserves exact rounding" % id)
		t.equal(world._nearest(123.987653287647, -73.19454833333),
			legacy._nearest(123.987653287647, -73.19454833333), "double-precision inputs retain original projection")
	arena.circuit_line = PackedVector3Array([
		Vector3(-10, 7, 0), Vector3(10, 7, 0), Vector3(30, 3, 30), Vector3(40, 3, 30),
		Vector3(50, 3, 30), Vector3(60, 3, 30), Vector3(70, 3, 30), Vector3(80, 3, 30),
		Vector3(0, 20, -10), Vector3(0, 20, 10), Vector3(-60, 2, 30), Vector3(-70, 2, 30)])
	t.equal(world._nearest(0, 0), Vector3(0, 7, 0), "cross-group exact ties retain the first road's height")
	var bounds: Array = world._road_query_bounds.duplicate()
	arena.circuit_line[0] = Vector3(-1000, 70, -1000)
	t.equal(arena.circuit_line[0], Vector3(-1000, 70, -1000), "test edits the actual route before checking invalidation")
	t.equal(world._nearest(0, 0), legacy._nearest(0, 0), "edited route updates a previously cached query")
	t.ok(world._road_query_bounds != bounds, "edited horizontal geometry refreshes rejection bounds")
	arena.circuit_line = PackedVector3Array()
	t.equal(world._nearest(0, 0), legacy._nearest(0, 0), "empty routes retain the original no-distance result")
	t.equal(world._road_query_bounds.size(), 0, "empty routes release cached bounds")
	world.free()
	legacy.free()
	arena.free()
