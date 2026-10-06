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
	await _shared_arena(t, host)
	await _safe_shapes(t, host)


func _shared_arena(t: TestHarness, host: Node) -> void:
	var window := host.get_tree().root
	var original := window.size
	var arena := Arena.new()
	arena.def = Registry.arena("star_meadow")
	arena.current_radius = arena.def.radius
	host.add_child(arena)
	arena.global_position = Vector3(120, 5, -80)
	var camera := ArenaCamera.new()
	host.add_child(camera)
	camera.set_process(false)
	camera.configure(ArenaCamera.Mode.ARENA, arena)
	var player := Node3D.new()
	host.add_child(player)
	player.global_position = arena.global_position + Vector3(-arena.current_radius * 0.6, 0, 0)
	camera.targets = [player]
	camera.shared_touch_count = 1
	for resolution in [Vector2i(720, 1280), Vector2i(1280, 720), Vector2i(540, 960)]:
		window.size = resolution
		await host.get_tree().process_frame
		var view := host.get_viewport().get_visible_rect().size
		var portrait := view.x < view.y
		var hud_bottom := 240.0 if portrait else 110.0
		camera.shared_hud_bottom = func(): return hud_bottom
		camera._process(1.0 / 60.0)
		for index in 32:
			var angle := TAU * index / 32.0
			for height in [0.0, 2.0]:
				var point := arena.global_position + Vector3(cos(angle) * arena.current_radius, height, sin(angle) * arena.current_radius)
				var screen := camera.unproject_position(point)
				t.ok(not camera.is_position_behind(point), "arena boundary is in front of shared camera")
				t.ok(screen.x >= view.x * 0.06 - 1 and screen.x <= view.x * 0.94 + 1, "clustered players cannot crop opposite arena edge")
				t.ok(screen.y >= hud_bottom + 24 - 1 and screen.y <= view.y * (0.76 if portrait else 0.80) + 1, "arena boundary stays between HUD and touch controls")
	for node in [player, camera, arena]:
		node.queue_free()
	await host.get_tree().process_frame
	window.size = original


func _safe_shapes(t: TestHarness, host: Node) -> void:
	var window := host.get_tree().root
	var original := window.size
	for mode in [ArenaCamera.Mode.ARENA, ArenaCamera.Mode.TOP_DOWN, ArenaCamera.Mode.ISOMETRIC]:
		var arena := Arena.new()
		arena.def = Registry.arena("tank_foundry")
		arena.current_radius = arena.def.radius
		host.add_child(arena)
		arena.global_position = Vector3(-80, 7, 120)
		var camera := ArenaCamera.new()
		host.add_child(camera)
		camera.set_process(false)
		camera.configure(mode, arena)
		camera.shared_touch_count = 4
		for resolution in [Vector2i(720, 1280), Vector2i(1280, 720)]:
			window.size = resolution
			await host.get_tree().process_frame
			var view := host.get_viewport().get_visible_rect().size
			camera.shared_hud_bottom = func(): return view.y * 0.22
			camera._process(1.0 / 60.0)
			var safe := camera.arena_safe_rect(view)
			t.ok(safe.position.y >= view.y * 0.22 + 24.0, "safe region reserves HUD height")
			t.ok(safe.end.y <= TouchSource.party_region(view, 0, 4).position.y, "safe region reserves four-player controls")
			for x in [-arena.current_radius, arena.current_radius]:
				for z in [-arena.current_radius, arena.current_radius]:
					for height in [0.0, 3.0]:
						var point := arena.global_position + Vector3(x, height, z)
						t.ok(not camera.is_position_behind(point), "square corners remain in front of camera")
						t.ok(safe.grow(1.0).has_point(camera.unproject_position(point)), "translated square fits safely in each shared viewing mode")
		camera.queue_free()
		arena.queue_free()
		await host.get_tree().process_frame
	window.size = original
