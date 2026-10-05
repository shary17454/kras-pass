extends RefCounted

const Floor = preload("res://src/arenas/crater_floor.gd")

class UnfilteredFloor extends "res://src/arenas/crater_floor.gd":
	func _cut_overlaps_sector(_sector: Rect2, _cut: Rect2) -> bool:
		return true

class CountedFloor extends "res://src/arenas/crater_floor.gd":
	var considered := 0
	var retained := 0
	func _cut_overlaps_sector(sector: Rect2, cut: Rect2) -> bool:
		considered += 1
		var result := super._cut_overlaps_sector(sector, cut)
		if result:
			retained += 1
		return result

func run(t: TestHarness, host: Node) -> void:
	t.suite("conservative crater clipping bounds")
	var fast := CountedFloor.new()
	var reference := UnfilteredFloor.new()
	host.add_child(fast)
	host.add_child(reference)
	fast.build(16.0, 1.0, StandardMaterial3D.new())
	reference.build(16.0, 1.0, StandardMaterial3D.new())
	var fixtures: Array = [
		[],
		[{"point": Vector2(8, 0), "radius": 3.0}],
		[{"point": Vector2.ZERO, "radius": 3.0}],
		[{"point": Vector2(4, 0), "radius": 3.0}, {"point": Vector2(6, 0), "radius": 3.0}],
		[{"point": Vector2(18, 0), "radius": 3.0}],
		[{"point": Vector2.ZERO, "radius": 20.0}],
		[{"point": Vector2(30, 30), "radius": 3.0}],
	]
	var many: Array = []
	for index in 12:
		var angle := TAU * index / 12.0
		many.append({"point": Vector2(cos(angle), sin(angle)) * 10.0, "radius": 3.0})
	fixtures.append(many)
	for fixture in fixtures:
		for arena_radius in [16.0, 8.0]:
			fast.apply_snapshot(arena_radius, fixture)
			reference.apply_snapshot(arena_radius, fixture)
			await host.get_tree().physics_frame
			await host.get_tree().physics_frame
			var actual: PackedVector3Array = fast._shape.shape.get_faces()
			var expected: PackedVector3Array = reference._shape.shape.get_faces()
			t.equal(actual.size(), expected.size(), "bounded clipping preserves triangle count")
			t.near(_area(actual), _area(expected), 0.001, "carved surface area matches unfiltered geometry")
			var probes: Array[Vector2] = []
			for x in range(-17, 18):
				for y in range(-17, 18):
					probes.append(Vector2(x + 0.13, y + 0.17))
			for hole in fixture:
				for step in 48:
					var angle := TAU * step / 48.0
					for offset in [-0.01, 0.01]:
						probes.append(hole.point + Vector2(cos(angle), sin(angle)) * (float(hole.radius) + offset))
			var differences := 0
			for point in probes:
				if _ground(fast, reference, point) != _ground(reference, fast, point):
					differences += 1
			t.equal(differences, 0, "physical coverage matches baseline across floor and crater rims")
			if not actual.is_empty():
				var rendered: PackedVector3Array = fast._mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				t.equal(rendered, actual, "visible floor and collider share identical triangles")
			t.ok(fast._cut_overlaps_sector(Rect2(0, 0, 1, 1), Rect2(1, 0, 1, 1)), "touching bounds stay on exact clipping path")
			t.ok(fast._cut_overlaps_sector(Rect2(0, 0, 1, 1), Rect2(1.0005, 0, 1, 1)), "rounding tolerance remains conservative")
	fast.considered = 0
	fast.retained = 0
	fast.apply_snapshot(16.0, [{"point": Vector2(8, 0), "radius": 3.0}])
	t.equal(fast.considered, Floor.SECTORS, "one crater checks each sector once")
	t.ok(fast.retained < Floor.SECTORS / 2, "remote sectors bypass exact polygon clipping")
	print("CRATER BOUNDS: considered=%d retained=%d" % [fast.considered, fast.retained])
	for node in [reference, fast]:
		node.apply_snapshot(16.0, many)
		var times: Array[int] = []
		for iteration in 12:
			var start := Time.get_ticks_usec()
			node._rebuild()
			times.append(Time.get_ticks_usec() - start)
		times.sort()
		print("CRATER REBUILD: filtered=%s median_usec=%d" % [node == fast, times[times.size() / 2]])
	fast.queue_free()
	reference.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame

func _area(faces: PackedVector3Array) -> float:
	var area := 0.0
	for index in range(0, faces.size(), 3):
		area += (faces[index + 1] - faces[index]).cross(faces[index + 2] - faces[index]).length() * 0.5
	return area

func _ground(node: Node3D, other: Node3D, point: Vector2) -> bool:
	var position := Vector3(point.x, 0, point.y)
	var ray := PhysicsRayQueryParameters3D.create(position + Vector3.UP, position + Vector3.DOWN, 1)
	ray.exclude = [other._body.get_rid()]
	return not node.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
