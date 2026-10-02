extends RefCounted
## Uses visible geometry only; no velocities, health, hidden targets or RNG.

static func build(position: Vector3, center: Vector3, radius: float, slag: Array, crates: Array) -> Dictionary:
	for index in 2:
		var hot := index == 0
		var group: Array = slag if hot else crates
		var best := {}
		var nearest := INF
		for point: Vector3 in group:
			var radial := Vector3(point.x - center.x, 0, point.z - center.z)
			if radial.length() > radius - 1.5 or radial.length() < 0.01:
				continue
			var outward := radial.normalized()
			var target := point + outward * (0.9 if hot else 1.5)
			var to := Vector3(point.x - position.x, 0, point.z - position.z)
			var distance := Vector2(target.x - position.x, target.z - position.z).length_squared()
			if distance >= nearest:
				continue
			nearest = distance
			# A blow pushes away from the fighter, so the fighter must be outside.
			var aligned := -to.normalized().dot(outward) > 0.9
			best = {"target": target, "attack": aligned and to.length() < (1.25 if hot else 2.7), "hot": hot}
		if not best.is_empty():
			return best
	return {}
