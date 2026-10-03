extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("world camera boundary")
	var arena := Arena.new()
	arena.def = Registry.arena("tank_foundry")
	arena.current_radius = arena.def.radius
	host.add_child(arena)
	arena.global_position = Vector3(120, 5, -80)
	var camera := ArenaCamera.new()
	host.add_child(camera)
	camera.set_process(false)
	camera.configure(ArenaCamera.Mode.WORLD, arena)
	var driver := Node3D.new()
	var survivor := Node3D.new()
	host.add_child(driver)
	host.add_child(survivor)
	camera.targets = [driver, survivor]
	camera.local_target = driver
	var origin := arena.global_position
	driver.global_position = origin + Vector3(40, 0, 40)
	survivor.global_position = origin
	t.test("valid square corner remains the follow subject")
	t.ok(camera._wanted_focus().is_equal_approx(driver.global_position), "square corner beyond the inscribed circle is not cropped")
	t.test("falling driver does not take the view away from survivors")
	driver.global_position = origin + Vector3(90, -12, 90)
	t.ok(camera._wanted_focus().is_equal_approx(survivor.global_position), "still-alive falling subject yields to an in-bounds survivor")
	t.test("all falling subjects remain bounded by the authored square")
	survivor.global_position = origin + Vector3(-90, -12, -90)
	var focus := camera._wanted_focus() - origin
	t.ok(absf(focus.x) <= arena.current_radius and absf(focus.z) <= arena.current_radius, "fallback focus stays inside both translated world axes")
	t.ok(focus.y >= -1.0, "fallback does not descend with a falling target")
	camera.local_target = null
	focus = camera._wanted_focus() - origin
	t.ok(absf(focus.x) <= arena.current_radius and absf(focus.z) <= arena.current_radius, "spectator fallback is also bounded")
	camera.targets.clear()
	camera.focus = origin + Vector3(100, -10, 100)
	focus = camera._wanted_focus() - origin
	t.ok(absf(focus.x) <= arena.current_radius and absf(focus.z) <= arena.current_radius, "empty-target fallback cannot retain an invalid focus")
	for node in [driver, survivor, camera, arena]:
		node.queue_free()
	await host.get_tree().process_frame
