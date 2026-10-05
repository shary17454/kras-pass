extends RefCounted

func run(t: TestHarness, host: Node) -> void:
	t.suite("live match memory pressure")
	for game in ["turret_duel", "gem_grab"]:
		t.test(game + " keeps live pool factories after memory warning")
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build(game, ["nabta", "sakhra", "fanoos", "ramla"], 0, 1, 77), "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		for fighter in scene.ctx.fighters:
			fighter.set_physics_process(false)
		var controller: Node = scene.controller
		var key: String = controller.POOL_KEY
		if game == "turret_duel":
			controller._fire(0)
		var objects: Array = controller._shots if game == "turret_duel" else controller._items
		var existing := objects.size()
		var live: Node = objects[0]
		var count := int(Pool.stats()[key].live)
		var before := OS.get_static_memory_usage()
		Platform._on_memory_warning()
		t.empty(MeshFactory._mat_cache, "unused cached materials are released")
		t.empty(MeshFactory._tex_cache, "unused cached textures are released")
		t.empty(MeshFactory._mesh_cache, "unused cached meshes are released")
		t.ok(Pool._factories.has(key), "memory pressure retains the active match factory")
		t.equal(int(Pool.stats().get(key, {}).get("live", -1)), count, "checked-out count survives pressure")
		t.equal(int(Pool.stats().get(key, {}).get("free", -1)), 0, "only unused instances are discarded")
		for frame in 3:
			await host.get_tree().process_frame
		t.ok(is_instance_valid(live) and live.is_inside_tree(), "checked-out object survives deferred trimming")
		if Pool._factories.has(key):
			if game == "turret_duel":
				controller._fire(1)
			else:
				controller._spawn_gem(Vector3(0, 1, 0))
		t.equal(objects.size(), existing + 1, "game can create the next projectile or collectible")
		Platform._on_memory_warning()
		t.equal(int(Pool.stats().get(key, {}).get("live", -1)), count + 1, "repeated warnings preserve newly acquired live objects")
		print("MEMORY_PRESSURE game=", game, " before=", before, " after=", OS.get_static_memory_usage())
		scene.teardown()
		scene.queue_free()
		for frame in 40:
			await host.get_tree().process_frame
		t.empty(Pool.stats(), "final match cleanup still removes every pool")
