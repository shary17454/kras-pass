extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("sweeper character jump clearance")
	var world := Node3D.new()
	host.add_child(world)
	world.position.y = 1000.0
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(20, 1, 20)
	collider.shape = floor_shape
	floor_body.add_child(collider)
	world.add_child(floor_body)
	floor_body.position.y = -0.5
	var sweeper := ArenaHazards.Sweeper.new()
	world.add_child(sweeper)
	sweeper.build(Color.WHITE, 8.0, 0.85)
	var tested := 0
	for character in Registry.characters():
		var body := Fighter.new()
		world.add_child(body)
		body.set_physics_process(false)
		body.data = character
		body._apply_character()
		body.global_position = world.global_position + Vector3(3, 1, 0)
		for step in 60:
			await host.get_tree().physics_frame
			body.tick(InputFrame.new(), 1.0 / 60.0)
		t.ok(body.is_on_floor(), "%s starts on a real floor" % character.id)
		t.ok(sweeper._area.get_overlapping_bodies().has(body), "%s grounded capsule intersects the blade" % character.id)
		var input := InputFrame.new()
		input.bits = InputFrame.Btn.JUMP
		body.tick(input, 1.0 / 60.0)
		t.ok(body.velocity.y > 1.0, "%s jump input produces actual upward motion" % character.id)
		var apex := body.global_position.y
		var cleared := false
		var clear_ticks := 0
		for step in 75:
			await host.get_tree().physics_frame
			if body.global_position.y > world.global_position.y + 1.2 \
					and not sweeper._area.get_overlapping_bodies().has(body):
				cleared = true
				clear_ticks += 1
			body.tick(InputFrame.new(), 1.0 / 60.0)
			apex = maxf(apex, body.global_position.y)
		t.ok(cleared, "%s actual jump clears the physical blade" % character.id)
		t.ok(body.is_on_floor(), "%s returns to the floor without an infinite jump" % character.id)
		print("SWEEPER_JUMP_CLEARANCE=%s" % JSON.stringify({"character": character.id,
			"apex": apex - world.global_position.y, "cleared": cleared,
			"clear_seconds": float(clear_ticks) / 60.0}))
		body.queue_free()
		await host.get_tree().process_frame
		tested += 1
	t.equal(tested, 8, "all eight registered characters are tested")
	world.queue_free()
	await host.get_tree().process_frame
