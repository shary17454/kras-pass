extends RefCounted

static func approach(origin: Vector3, rival: Vector3, center: Vector3, clear: bool) -> Vector3:
	var separation := rival - origin
	separation.y = 0.0
	return rival if clear and separation.length() <= 22.0 else center


static func throttle(distance: float, aligned: float, clear: bool) -> float:
	return 0.0 if clear and distance <= 12.0 and aligned > 0.9 else 1.0
