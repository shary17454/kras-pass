extends RefCounted

class HitProbe extends Fighter:
	var hits := 0

	func take_hit(_slot: int, _direction: Vector3, _strength: float, _damage: float = 0.0, _ignore_shield: bool = false) -> bool:
		hits += 1
		return true


func run(t: TestHarness, host: Node) -> void:
	t.suite("sweeper visible physical bounds")
	for angle in [0.0, 0.7, -1.4]:
		var world := Node3D.new()
		host.add_child(world)
		world.position.y = 1000.0
		var sweeper := ArenaHazards.Sweeper.new()
		world.add_child(sweeper)
		sweeper.build(Color.WHITE, 8.0, 0.85)
		sweeper.rotation.y = angle
		var collider := sweeper._area.get_child(0) as CollisionShape3D
		var shape := collider.shape as BoxShape3D
		var visible := sweeper._arm_mesh.mesh.get_aabb()
		t.equal(shape.size, visible.size, "collision dimensions match the actual rendered blade")
		t.equal(collider.position, sweeper._arm_mesh.position + visible.get_center(), "collision and mesh have the same local centre")
		var body := HitProbe.new()
		world.add_child(body)
		body.set_physics_process(false)
		# The capsule bottom clears the rendered blade's top, but not the old
		# taller hitbox. Freeze motion to test actual physics overlap precisely.
		body.global_position = sweeper.to_global(Vector3(3.0, 1.20, 0.0))
		await _settle(host)
		t.ok(not sweeper._area.get_overlapping_bodies().has(body), "jump clear of visible top does not overlap an invisible extension")
		sweeper.tick(0.0)
		t.equal(body.hits, 0, "jump clear of visible top cannot receive a phantom hit")
		body.hits = 0
		body.global_position = sweeper.to_global(Vector3(3.0, 0.0, 0.79))
		await _settle(host)
		t.ok(not sweeper._area.get_overlapping_bodies().has(body), "capsule clear of visible side does not overlap an invisible extension")
		sweeper.tick(0.0)
		t.equal(body.hits, 0, "visible side clearance cannot receive a phantom hit")
		body.hits = 0
		body.global_position = sweeper.to_global(Vector3(3.0, 0.0, 0.0))
		await _settle(host)
		t.ok(sweeper._area.get_overlapping_bodies().has(body), "fighter inside the rendered blade still overlaps")
		sweeper.tick(0.0)
		t.equal(body.hits, 1, "actual blade contact still delivers one hit")
		world.queue_free()
		await host.get_tree().process_frame


func _settle(host: Node) -> void:
	for _frame in range(4):
		await host.get_tree().physics_frame
