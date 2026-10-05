extends Node3D
## Frozen pre-optimization road query from d776c78236e29e150b6e5ad37acf84e36163a99e.

var arena: Arena


func _nearest(x: float, z: float) -> Vector3:
	var best := INF
	var result := Vector3.ZERO
	for i in arena.circuit_line.size():
		var a := arena.circuit_line[i]
		var b := arena.circuit_line[(i + 1) % arena.circuit_line.size()]
		var segment := Vector2(b.x - a.x, b.z - a.z)
		var t := clampf(Vector2(x - a.x, z - a.z).dot(segment) / segment.length_squared(), 0.0, 1.0)
		var p := a.lerp(b, t)
		var d := Vector2(x, z).distance_squared_to(Vector2(p.x, p.z))
		if d < best:
			best = d
			result = p
	return Vector3(sqrt(best), result.y, 0)
