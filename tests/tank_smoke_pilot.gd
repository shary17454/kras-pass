extends RefCounted

static func approach(origin: Vector3, rival: Vector3, center: Vector3, clear: bool) -> Vector3:
	var separation := rival - origin
	separation.y = 0.0
	return rival if clear and separation.length() <= 22.0 else center


static func throttle(distance: float, aligned: float, clear: bool) -> float:
	return 0.0 if clear and distance <= 12.0 and aligned > 0.9 else 1.0


static func can_fire(origin: Vector3, rival: Vector3, facing: Vector3, clear: bool) -> bool:
	if not clear or absf(rival.y - origin.y) > 0.6:
		return false
	var offset := rival - origin
	offset.y = 0.0
	var direction := facing
	direction.y = 0.0
	if direction.length_squared() < 0.0001 or offset.length() > 22.0:
		return false
	direction = direction.normalized()
	var forward := offset.dot(direction)
	if forward <= 1.8:
		return false
	# A broad dot-product cone can miss a narrow chassis even at short range.
	return (offset - direction * forward).length() <= 0.4
