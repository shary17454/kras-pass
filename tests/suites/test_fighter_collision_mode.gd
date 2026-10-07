extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("fighter collision follows configured locomotion")
	for setup_before_ready in [false, true]:
		var fighter := Fighter.new()
		if setup_before_ready:
			fighter.setup(0, Registry.characters()[0], Fighter.Locomotion.DRIVE)
		host.add_child(fighter)
		fighter.set_physics_process(false)
		if not setup_before_ready:
			fighter.setup(0, Registry.characters()[0], Fighter.Locomotion.DRIVE)
		var body: CollisionShape3D = fighter.get_node("Body")
		t.ok(body.shape is BoxShape3D, "vehicle box is independent of ready/setup order")
		if body.shape is BoxShape3D:
			t.equal(body.shape.size, Vector3(1.4, 0.9, 2.0), "vehicle collision uses authored dimensions")
			t.equal(body.position, Vector3(0, 0.55, 0), "vehicle collision uses authored offset")
		fighter.set_game_scale(1.5)
		if body.shape is BoxShape3D:
			t.equal(body.shape.size, Vector3(1.4, 0.9, 2.0) * 1.5, "vehicle scale resizes collision")
			t.ok(is_equal_approx(body.position.y, 0.55 * 1.5), "vehicle scale resizes collision offset")
		fighter.setup(0, Registry.characters()[0], Fighter.Locomotion.WALK)
		t.equal(fighter.get_node("Body"), body, "reconfiguration retains one collision node")
		t.ok(body.shape is CapsuleShape3D, "walking reconfiguration uses capsule")
		if body.shape is CapsuleShape3D:
			t.ok(is_equal_approx(body.shape.radius, 0.42 * 1.5), "reconfiguration preserves active size modifier")
		fighter.queue_free()
		await host.get_tree().process_frame
