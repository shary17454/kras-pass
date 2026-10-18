extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("bounded debug operation tracing")
	var trace := OperationTrace.new()
	trace.configure(false, true)
	t.equal(trace.begin(), 0, "release policy cannot activate clocks")
	trace.record("disabled", 1, 9000, 1, 1)
	t.ok(trace.report().costs.is_empty(), "release policy cannot collect records")
	trace.configure(true, false)
	t.equal(trace.begin(), 0, "debug builds require explicit opt-in")
	trace.configure(true, true)
	trace.record("ai", 100, 4099, 7, 9)
	t.equal(trace.report().slow_count, 0, "slow threshold is not rounded up")
	trace.record("ai", 100, 4100, 8, 10)
	t.equal(trace.report().slow_count, 1, "inclusive threshold records the actual interval")
	trace.record("bad", 10, 9, 1, 1)
	trace.record("bad", 0, 9, 1, 1)
	trace.record("", 1, 9, 1, 1)
	trace.record("x".repeat(65), 1, 9, 1, 1)
	t.equal(trace.report().costs.size(), 1, "invalid intervals and unbounded tags are excluded")
	for index in 20:
		trace.record("ai", 100, 5100 + index, 12, 13)
	var report := trace.report()
	t.equal(report.slow_count, 21, "all qualifying intervals are counted")
	t.equal(report.retained.size(), 8, "retained slow intervals are bounded")
	t.equal(report.retained[0].elapsed_usec, 5019, "worst interval is retained first")
	t.equal(report.retained[0].physics_frame, 12, "physics correlation uses supplied frame identity")
	t.equal(report.costs.ai.calls, 22, "aggregate counts include subthreshold intervals")
	report.costs.ai.calls = 0
	report.retained[0].tag = "mutated"
	t.equal(trace.report().costs.ai.calls, 22, "report cannot mutate internal aggregates")
	t.equal(trace.report().retained[0].tag, "ai", "report cannot mutate retained intervals")
	for index in 100:
		trace.record("tag%d" % index, 100, 101, 1, 1)
	t.equal(trace.report().costs.size(), 32, "aggregate tags are independently bounded")
	trace.reset()
	t.ok(trace.report().costs.is_empty() and trace.report().retained.is_empty(), "next probe resets all retained state")
	t.equal(trace.report().slow_count, 0, "next probe resets the slow count")
	trace.configure(false, true)
	trace.finish("disabled", 1)
	t.ok(trace.report().costs.is_empty(), "disabled finish is harmless")
	trace.finish_physics(null, 0, 1)
	t.ok(trace.report().physics_contacts.is_empty(), "release-disabled trace cannot read or retain body contacts")
	var fixture := Node3D.new()
	host.add_child(fixture)
	fixture.position = Vector3(1000, 0, 1000)
	var floor_body := StaticBody3D.new()
	floor_body.name = "ObservedFloor"
	fixture.add_child(floor_body)
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 1, 10)
	floor_shape.shape = box
	floor_shape.position.y = -0.5
	floor_body.add_child(floor_shape)
	var actor := CharacterBody3D.new()
	fixture.add_child(actor)
	actor.position.y = 1.0
	var actor_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.0
	capsule.radius = 0.25
	actor_shape.shape = capsule
	actor.add_child(actor_shape)
	for frame in 12:
		await host.get_tree().physics_frame
		actor.velocity = Vector3(0, -5, 0)
		actor.move_and_slide()
	t.ok(actor.is_on_floor(), "diagnostic fixture has an actual observed floor contact")
	trace.configure(true, true)
	for index in 20:
		trace.finish_physics(actor, 2, Time.get_ticks_usec() - 5000 - index * 100)
	var physics: Dictionary = trace.report()
	t.equal(physics.physics_slow_count, 20, "physics intervals are counted independently of parent operations")
	t.equal(physics.physics_contacts.size(), 8, "contact diagnostics retain at most eight intervals")
	t.equal(physics.physics_contacts[0].slot, 2, "contact diagnostic preserves the actor slot")
	t.ok(physics.physics_contacts[0].contacts.has({"node": "ObservedFloor", "class": "StaticBody3D"}), "contact report records an actual static collider")
	t.ok(physics.physics_contacts[0].contacts.size() <= 8, "each retained contact payload stays bounded")
	physics.physics_contacts[0].contacts[0].node = "mutated"
	t.equal(trace.report().physics_contacts[0].contacts[0].node, "ObservedFloor", "reported diagnostics cannot mutate internal snapshots")
	trace.reset()
	t.ok(trace.report().physics_contacts.is_empty() and trace.report().physics_slow_count == 0, "reset releases physics diagnostics")
	fixture.queue_free()
	await host.get_tree().process_frame
