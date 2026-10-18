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
	await _colossus_visibility(t, host)
	await _portrait_readability(t, host)
	await _oasis_sightlines(t, host)


func _oasis_sightlines(t: TestHarness, host: Node) -> void:
	t.test("oasis natural spawn camera sightlines")
	var window := host.get_tree().root
	var original_size := window.size
	var cfg := MatchConfig.build("tank_arena", ["nabta", "sakhra", "fanoos", "ramla"], 4, 1, 250925)
	cfg.arena_id = "tank_oasis"
	for player in cfg.players:
		player.device_type = 2
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg})
	scene._set_phase(MatchPhase.P.INSTRUCTIONS)
	scene._set_phase(MatchPhase.P.COUNTDOWN)
	scene._set_phase(MatchPhase.P.PLAYING)
	for frame in 144:
		await host.get_tree().physics_frame
	for resolution in [Vector2i(540, 960), Vector2i(1280, 720)]:
		window.size = resolution
		for frame in 24:
			await host.get_tree().physics_frame
		for index in 4:
			var camera: ArenaCamera = scene.vehicle_views.cameras[index]
			var fighter: Fighter = scene.ctx.fighter(index)
			for height in [0.3, 0.6, 1.0, 2.0]:
				var subject: Vector3 = fighter.global_position + Vector3.UP * height
				var ray := PhysicsRayQueryParameters3D.create(subject, camera.global_position, 1, [fighter.get_rid()])
				var hit := camera.get_world_3d().direct_space_state.intersect_ray(ray)
				print("OASIS_SIGHTLINE slot=%d height=%s subject=%s camera=%s collider=%s" % [index, height, subject, camera.global_position, hit.get("collider", "none")])
				t.ok(hit.is_empty(), "natural spawn vehicle centre is unobstructed at height %s, slot %d" % [height, index])
			for corner in [Vector3(-1.3, 0.15, -1.3), Vector3(1.3, 0.15, -1.3), Vector3(-1.3, 0.15, 1.3), Vector3(1.3, 0.15, 1.3)]:
				var ray := PhysicsRayQueryParameters3D.create(fighter.global_position + corner, camera.global_position, 1, [fighter.get_rid()])
				t.ok(camera.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "vehicle footprint corners clear cover in both orientations")
			var bounds: Rect2 = load("res://tests/suites/test_local_vehicle_views.gd").visual_bounds(camera, fighter)
			t.ok(Rect2(Vector2.ZERO, Vector2(camera.get_viewport().size)).encloses(bounds), "obstruction recovery does not crop the vehicle")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
	window.size = original_size


func _portrait_readability(t: TestHarness, host: Node) -> void:
	t.test("portrait arena uses vertical play space without cropping the rim")
	var window := host.get_tree().root
	var original := window.size
	for id in ["scrap_yard", "star_meadow"]:
		var arena := Arena.new()
		arena.def = Registry.arena(id)
		arena.current_radius = arena.def.radius
		host.add_child(arena)
		var camera := ArenaCamera.new()
		host.add_child(camera)
		camera.set_process(false)
		camera.configure(ArenaCamera.Mode.ARENA, arena)
		camera.shared_touch_count = 1
		camera.shared_hud_bottom = func(): return 180.0
		for resolution in [Vector2i(540, 960), Vector2i(720, 1280)]:
			window.size = resolution
			await host.get_tree().process_frame
			camera._process(1.0 / 60.0)
			var view := host.get_viewport().get_visible_rect().size
			var safe := camera.arena_safe_rect(view)
			var bounds := Rect2(camera.unproject_position(arena.global_position), Vector2.ZERO)
			for index in 32:
				var angle := TAU * index / 32.0
				var point := arena.global_position + Vector3(cos(angle), 0, sin(angle)) * arena.current_radius
				if arena.def.shape == "square":
					point = arena.global_position + Vector3(signf(cos(angle)), 0, signf(sin(angle))) * arena.current_radius
				var screen := camera.unproject_position(point)
				bounds = bounds.expand(screen)
				t.ok(safe.grow(1.0).has_point(screen), "all sampled rim points remain within the play region")
			t.ok(bounds.size.y >= minf(safe.size.y * 0.50, view.x * 0.60), "portrait floor is not flattened into a narrow strip")
			t.ok(bounds.size.x >= safe.size.x * 0.82, "steeper portrait view does not shrink the arena width")
		camera.queue_free()
		arena.queue_free()
		await host.get_tree().process_frame
	window.size = original


func _colossus_visibility(t: TestHarness, host: Node) -> void:
	t.test("colossus rear spawn remains visible")
	var window := host.get_tree().root
	var original := window.size
	var controller := load("res://src/minigames/boss_colossus.gd").new() as MiniGameController
	t.ok(controller.camera_mode() == ArenaCamera.Mode.TOP_DOWN, "tall central boss requests an overhead gameplay view")
	var arena := Arena.new()
	arena.def = Registry.arena("vortex_ring")
	arena.current_radius = arena.def.radius
	host.add_child(arena)
	var camera := ArenaCamera.new()
	host.add_child(camera)
	camera.set_process(false)
	camera.configure(controller.camera_mode(), arena)
	camera.shared_touch_count = 1
	for resolution in [Vector2i(1280, 720), Vector2i(540, 960)]:
		window.size = resolution
		await host.get_tree().process_frame
		camera.shared_hud_bottom = func(): return 110.0 if resolution.x > resolution.y else 270.0
		camera._process(1.0 / 60.0)
		t.ok(rad_to_deg(camera.rotation.x) <= -75.0, "overhead mode retains its steep gameplay angle after safe-area fitting")
		# Rear spawn ray must clear the actual 8.8-metre top of the boss head.
		var rear := arena.global_position + Vector3(0, 1.0, -7.44)
		var crossing := (arena.global_position.z - rear.z) / (camera.global_position.z - rear.z)
		var ray_height := lerpf(rear.y, camera.global_position.y, crossing)
		t.ok(ray_height > arena.global_position.y + 8.8, "rear player sightline clears the central boss rather than relying on a HUD marker")
		var view := host.get_viewport().get_visible_rect().size
		t.ok(camera.arena_safe_rect(view).grow(1.0).has_point(camera.unproject_position(rear)), "rear player remains between HUD and controls")
	controller.free()
	camera.queue_free()
	arena.queue_free()
	await host.get_tree().process_frame
	window.size = original


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
