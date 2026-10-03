extends RefCounted

class HitProbe extends Fighter:
	var hits: Array[Vector3] = []
	var strengths: Array[float] = []
	func take_hit(_from_slot: int, direction: Vector3, strength: float, _damage: float = 0.0, _ignore_shield: bool = false) -> bool:
		hits.append(direction)
		strengths.append(strength)
		return true


func run(t: TestHarness, host: Node) -> void:
	t.suite("sweeper physical impact direction")
	for angle in [0.0, 0.7, -1.4]:
		for speed in [1.0, -1.0]:
			var world := Node3D.new()
			host.add_child(world)
			var sweeper := ArenaHazards.Sweeper.new()
			world.add_child(sweeper)
			sweeper.build(Color.WHITE, 8.0, 0.85)
			sweeper.rotation.y = angle
			sweeper.speed = speed
			var body := HitProbe.new()
			world.add_child(body)
			body.set_physics_process(false)
			var outward := sweeper.global_transform.basis.x.normalized()
			body.global_position = sweeper.global_position + outward * 3.0
			await host.get_tree().physics_frame
			await host.get_tree().physics_frame
			t.ok(sweeper._area.get_overlapping_bodies().has(body), "real sweeper Area3D overlaps the stationary fighter")
			sweeper.tick(0.0)
			t.equal(body.hits.size(), 1, "physical overlap produces exactly one impact for one tick")
			if body.hits.size() == 1:
				var tangent := Vector3.UP.cross(outward) * signf(speed)
				var expected := (outward * 0.55 + tangent * 0.75).normalized()
				t.ok(body.hits[0].dot(expected) > 0.999, "impact follows the actual signed angular motion at every arm angle")
				t.ok(body.hits[0].dot(outward) > 0.0, "impact retains outward pressure rather than pulling toward the hub")
				t.near(body.strengths[0], sweeper.power, 0.0001, "direction correction does not change authored impact strength")
			world.queue_free()
			await host.get_tree().process_frame
