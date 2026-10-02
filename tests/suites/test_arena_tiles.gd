extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("arena tiles")
	var tile := ArenaTile.new()
	host.add_child(tile)
	tile.build(2.0, 0.5, Color.SKY_BLUE)
	tile.crumbles = true
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	var query := PhysicsRayQueryParameters3D.create(Vector3(0, 2, 0), Vector3(0, -2, 0), 1)
	t.ok(not tile.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "solid tile blocks a physical ray")
	var events := [0]
	tile.collapsed.connect(func(_tile): events[0] += 1)
	tile.force_collapse()
	t.ok(not tile.get_collision_layer_value(1), "forced collapse immediately removes floor collision")
	t.equal(events[0], 1, "forced collapse emits exactly one collapse event")
	tile.force_collapse()
	t.equal(events[0], 1, "repeated collapse is idempotent")
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	t.ok(tile.get_world_3d().direct_space_state.intersect_ray(query).is_empty(), "collapsed tile no longer blocks the physics world")
	tile.restore()
	tile.touch()
	tile.tick(0.2)
	var material := tile._mesh.material_override
	var cache_size := MeshFactory._mat_cache.size()
	var neutral := MeshFactory.toon(tile.base_color)
	for i in 100:
		tile.tick(0.001)
	t.equal(tile._mesh.material_override, material, "warning reuses a single owned material")
	t.equal(MeshFactory._mat_cache.size(), cache_size, "warning cannot grow shared material cache per tick")
	t.equal(neutral.albedo_color, tile.base_color, "warning never recolors shared neutral material")
	var warning_pose := tile._mesh.position
	await host.get_tree().create_timer(0.035).timeout
	tile.tick(0.0)
	t.equal(tile._mesh.position, warning_pose, "zero simulation delta cannot advance warning shake")
	tile._mesh.position.x = 0.04
	tile.restore()
	t.near(tile._mesh.position.x, 0.0, 0.00001, "restore clears warning displacement")
	t.ok(tile.visible and tile.get_collision_layer_value(1), "restore restores visibility and collision")
	tile.touch()
	tile.tick(tile.crumble_delay)
	t.equal(events[0], 2, "timed collapse also emits exactly once")
	t.ok(not tile.get_collision_layer_value(1), "timed collapse removes collision")
	for i in 120:
		tile.tick(1.0 / 60.0)
	t.equal(tile.state, ArenaTile.State.GONE, "fallen floor disappears")
	t.ok(not tile.visible, "gone floor is hidden")
	tile.tick(tile.respawn_time)
	t.equal(tile.state, ArenaTile.State.SOLID, "respawn restores solid state")
	t.near(tile.position.y, tile._home_y, 0.00001, "respawn restores authored height")
	tile.queue_free()
	await host.get_tree().process_frame
	var cfg := MatchConfig.build("color_stand", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 102)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	game._round_no = 10
	game._drop()
	game.on_round_start()
	t.equal(game._stage, game.Stage.CALL, "new color round starts with a call, not the prior drop")
	t.equal(game._round_no, 1, "new color round resets difficulty progression")
	t.ok(game._timer > 2.0, "new color round restores full reaction time")
	for floor_tile: ArenaTile in scene.arena.tiles:
		t.ok(floor_tile.is_standable() and floor_tile.get_collision_layer_value(1), "new color round restores every floor tile")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
