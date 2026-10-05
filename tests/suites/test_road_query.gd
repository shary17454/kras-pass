extends RefCounted


func run(t: TestHarness) -> void:
	t.suite("terrain road distance equivalence")
	var world: Node3D = load("res://src/arenas/natural_valley.gd").new()
	var arena := Arena.new()
	world.arena = arena
	var legacy: Node3D = load("res://tests/fixtures/road_query_legacy.gd").new()
	legacy.arena = arena
	var routes: Script = load("res://src/arenas/racing_routes.gd")
	var reference_usec := 0
	var production_usec := 0
	for id in Registry.minigame("sabaq_sawarikh").arena_ids:
		arena.circuit_line = routes.points(id)
		var queries: Array[Vector2] = []
		for z in 201:
			for x in 201:
				queries.append(Vector2(float(x - 100) * 3, float(z - 100) * 3))
		for p in arena.circuit_line:
			queries.append(Vector2(p.x, p.z))
		var expected: Array[Vector3] = []
		var started := Time.get_ticks_usec()
		for query in queries:
			expected.append(legacy._nearest(query.x, query.y))
		reference_usec += Time.get_ticks_usec() - started
		var actual: Array[Vector3] = []
		started = Time.get_ticks_usec()
		for query in queries:
			actual.append(world._nearest(query.x, query.y))
		production_usec += Time.get_ticks_usec() - started
		for i in queries.size():
			t.equal(actual[i], expected[i], "%s query %d retains exact road distance and height" % [id, i])
	# Crossing roads at different heights retain the first segment on exact ties.
	arena.circuit_line = PackedVector3Array([
		Vector3(-10, 7, 0), Vector3(10, 7, 0), Vector3(0, 20, -10), Vector3(0, 20, 10)])
	t.equal(world._nearest(0, 0), legacy._nearest(0, 0), "crossing roads preserve tie ordering")
	arena.circuit_line[0] = Vector3(-20, 30, -5)
	t.equal(world._nearest(-14, -2), legacy._nearest(-14, -2), "in-place route edits remain visible")
	arena.circuit_line = PackedVector3Array([Vector3(-1, -5, -1), Vector3(1, 9, 1)])
	t.equal(world._nearest(0, 0), legacy._nearest(0, 0), "replacing the route updates its height")
	print("ROAD_QUERY_BENCH reference_usec=%d production_usec=%d" % [reference_usec, production_usec])
	world.free()
	legacy.free()
	arena.free()
