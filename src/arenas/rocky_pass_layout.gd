extends RefCounted
## Original double-loop battlefield with equal cardinal approach routes.


static func points() -> PackedVector3Array:
	var result := PackedVector3Array()
	for ring in [Vector2i(16, 36), Vector2i(8, 18)]:
		for index in ring.x:
			var angle: float = TAU * float(index) / ring.x
			result.append(Vector3(cos(angle), 0, sin(angle)) * ring.y)
	result.append(Vector3.ZERO)
	return result


static func edges() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for index in 16:
		result.append(Vector2i(index, (index + 1) % 16))
	for index in 8:
		result.append(Vector2i(16 + index, 16 + (index + 1) % 8))
		result.append(Vector2i(index * 2, 16 + index))
	for index in 4:
		result.append(Vector2i(24, 16 + index * 2))
	return result


static func cover_positions() -> PackedVector3Array:
	var result := PackedVector3Array()
	for index in 8:
		var angle := TAU * (float(index) + 0.5) / 8.0
		result.append(Vector3(cos(angle), 0, sin(angle)) * 27.0)
	for radius in [12.0, 43.0]:
		for index in 4:
			var angle := TAU * (float(index) + 0.5) / 4.0
			result.append(Vector3(cos(angle), 0, sin(angle)) * radius)
	return result
