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
	_check_resistance_response(t)
	await _check_opening_grace(t, host)
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


func _check_opening_grace(t: TestHarness, host: Node) -> void:
	var world := Node3D.new()
	host.add_child(world)
	world.position.y = 1000.0
	var sweeper := ArenaHazards.Sweeper.new()
	world.add_child(sweeper)
	sweeper.build(Color.WHITE, 8.0, 0.85)
	t.near(sweeper.opening_grace, 0.0, 0.0001, "other modes have no added opening grace")
	sweeper.opening_grace = 1.0
	var body := HitProbe.new()
	world.add_child(body)
	body.set_physics_process(false)
	body.global_position = sweeper.global_position + Vector3.RIGHT * 3.0
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	t.ok(sweeper._area.get_overlapping_bodies().has(body), "grace test uses a real physical overlap")
	sweeper.tick(0.4)
	t.equal(body.hits.size(), 0, "opening overlap cannot hit while fighters land")
	t.ok(absf(sweeper.rotation.y) > 0.1, "arm still visibly rotates during grace")
	t.near(sweeper.current_speed(), sweeper.speed * 1.024, 0.0001, "motion acceleration is not paused by grace")
	body.global_position = sweeper.global_position + sweeper.global_transform.basis.x.normalized() * 3.0
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	sweeper.tick(0.59)
	t.equal(body.hits.size(), 0, "grace remains active before its boundary")
	body.global_position = sweeper.global_position + sweeper.global_transform.basis.x.normalized() * 3.0
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	t.ok(sweeper._area.get_overlapping_bodies().has(body), "contact is physically current when grace expires")
	sweeper.tick(0.02)
	t.equal(body.hits.size(), 1, "real contact hits again once the opening grace expires")
	sweeper._age = 0.0
	sweeper.tick(0.0)
	t.equal(body.hits.size(), 1, "round-age reset restores opening protection")
	t.near(float(Balance.table("tuning").get("sweeper_storm", {}).get("opening_grace", 0.0)),
		1.0, 0.0001, "Sweeper Storm explicitly configures one-second grace")
	world.queue_free()
	await host.get_tree().process_frame


func _check_resistance_response(t: TestHarness) -> void:
	var sweeper := ArenaHazards.Sweeper.new()
	t.ok(sweeper.has_method("impact_strength"), "sweeper supports a bounded character resistance influence")
	if not sweeper.has_method("impact_strength"):
		sweeper.free()
		return
	var neutral := Fighter.new()
	neutral.data = CharacterData.new()
	neutral._apply_character()
	for character in Registry.characters():
		var body := Fighter.new()
		body.data = character
		body._apply_character()
		var original := body.knock_resist
		sweeper.set("resistance_influence", 1.0)
		t.near(sweeper.call("impact_strength", body), sweeper.power, 0.00001, "other games keep authored strength")
		for influence in [0.25, 0.5]:
			sweeper.set("resistance_influence", influence)
			var incoming: float = sweeper.call("impact_strength", body)
			var relative_push := incoming / body.knock_resist / (sweeper.power / neutral.knock_resist)
			var expected := pow(neutral.knock_resist / body.knock_resist, influence)
			t.near(relative_push, expected, 0.00001, "weight retains the configured logarithmic influence")
			t.ok(absf(relative_push - 1.0) <= absf(neutral.knock_resist / body.knock_resist - 1.0) + 0.00001,
				"hazard cannot exaggerate the original character difference")
			t.near(body.knock_resist, original, 0.00001, "fighter combat and mass properties are unchanged")
		sweeper.set("resistance_influence", -1.0)
		t.near(sweeper.call("impact_strength", body) / body.knock_resist,
			sweeper.power / neutral.knock_resist, 0.00001, "lower clamp cannot invert light and heavy advantage")
		sweeper.set("resistance_influence", 2.0)
		t.near(sweeper.call("impact_strength", body), sweeper.power, 0.00001,
			"upper clamp cannot amplify light and heavy differences")
		body.free()
	for influence in [0.25, 0.5]:
		sweeper.set("resistance_influence", influence)
		t.near(sweeper.call("impact_strength", neutral), sweeper.power, 0.00001, "neutral character retains the original hazard power")
	sweeper.set("resistance_influence", -1.0)
	t.near(sweeper.call("impact_strength", neutral), sweeper.power, 0.00001, "low bound keeps neutral strength")
	sweeper.set("resistance_influence", 2.0)
	t.near(sweeper.call("impact_strength", neutral), sweeper.power, 0.00001, "high bound keeps neutral strength")
	neutral.free()
	sweeper.free()
