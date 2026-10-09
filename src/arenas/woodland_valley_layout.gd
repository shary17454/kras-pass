extends RefCounted
## Paired winding meadow routes, distinct from the rocky concentric passes.


static func points() -> PackedVector3Array:
	var left := PackedVector3Array([
		Vector3(-4, 0, -30), Vector3(-18, 0, -36), Vector3(-34, 0, -28),
		Vector3(-39, 0, -12), Vector3(-28.52, 0, 0), Vector3(-32, 0, 28),
		Vector3(-17, 0, 36), Vector3(-4, 0, 30), Vector3(-9, 0, 15),
		Vector3(-13, 0, 0), Vector3(-9, 0, -15),
	])
	var result := left.duplicate()
	for point in left:
		result.append(Vector3(-point.x, 0, point.z))
	result.append(Vector3(0, 0, -28.52))
	result.append(Vector3.ZERO)
	result.append(Vector3(0, 0, 28.52))
	return result


static func edges() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for start in [0, 11]:
		for index in 11:
			result.append(Vector2i(start + index, start + (index + 1) % 11))
	for edge in [Vector2i(0, 22), Vector2i(11, 22), Vector2i(9, 23),
		Vector2i(20, 23), Vector2i(7, 24), Vector2i(18, 24),
		Vector2i(22, 23), Vector2i(23, 24)]:
		result.append(edge)
	return result


static func cover_positions() -> PackedVector3Array:
	var left := PackedVector3Array([
		Vector3(-25, 0, -20), Vector3(-22, 0, 20), Vector3(-23, 0, -7),
		Vector3(-23, 0, 9), Vector3(-42, 0, -34), Vector3(-42, 0, 34),
		Vector3(-18, 0, -44), Vector3(-18, 0, 44),
	])
	var result := left.duplicate()
	for point in left:
		result.append(Vector3(-point.x, 0, point.z))
	return result
