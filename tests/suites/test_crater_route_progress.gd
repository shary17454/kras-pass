extends RefCounted

const Floor = preload("res://src/arenas/crater_floor.gd")

func run(t: TestHarness, host: Node) -> void:
	t.suite("crater route progress")
	var floor_node = Floor.new()
	host.add_child(floor_node)
	floor_node.build(16.0, 1.0, StandardMaterial3D.new())
	for count in [1, 3]:
		floor_node.reset()
		floor_node.open_hole(Vector3.ZERO, 3.0)
		if count == 3:
			floor_node.open_hole(Vector3(0, 0, 4), 3.0)
			floor_node.open_hole(Vector3(0, 0, -4), 3.0)
		for side in [-1.0, 1.0]:
			var position := Vector3(-6.0 * side, 0, 0)
			var target := Vector3(6.0 * side, 0, 0)
			var safe := true
			for step in 400:
				if position.distance_to(target) < 0.25:
					break
				var direction: Vector3 = floor_node.steering_direction(position, target)
				var next := position + direction * 0.15
				safe = safe and floor_node.path_clear(position, next, 0.5)
				position = next
			t.ok(safe, "complete detour preserves body clearance")
			t.ok(position.distance_to(target) < 0.25, "bot reaches target across %d craters instead of oscillating at their rim" % count)
	var grid: AStarGrid2D = floor_node._route_grid
	floor_node.steering_direction(Vector3(-6, 0, 0), Vector3(6, 0, 0))
	t.equal(floor_node._route_grid, grid, "unchanged terrain reuses its route grid")
	floor_node.open_hole(Vector3(0, 0, 8), 3.0)
	t.ok(floor_node._route_dirty, "new crater invalidates cached navigation")
	floor_node.steering_direction(Vector3(-6, 0, 0), Vector3(6, 0, 0))
	t.ok(floor_node._route_grid != grid, "changed terrain rebuilds route grid before use")
	t.equal(floor_node._route_waypoint(Vector3.ZERO, Vector3(6, 0, 0), 0.5), Vector3.INF, "carved start cannot fabricate a route")
	t.equal(floor_node._route_waypoint(Vector3(-6, 0, 0), Vector3.ZERO, 0.5), Vector3.INF, "carved destination cannot fabricate a route")
	floor_node.reset()
	t.ok(floor_node._route_dirty, "round reset invalidates previous crater routes")
	t.ok(floor_node.steering_direction(Vector3(-6, 0, 0), Vector3(6, 0, 0)).x > 0.99, "restored floor uses direct route again")
	floor_node.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
