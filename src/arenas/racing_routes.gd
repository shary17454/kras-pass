extends RefCounted
## Authored road layouts, baked through Godot's Curve3D rather than radial rings.

static func points(id: String) -> PackedVector3Array:
	var anchors: Array[Vector3] = []
	var length := 460.0
	match id:
		"dune_circuit":
			length = 430.0
			anchors = [Vector3(95, 1, -60), Vector3(115, 2, 5), Vector3(75, 3, 65), Vector3(5, 1, 90), Vector3(-70, 2, 65), Vector3(-110, 4, 10), Vector3(-80, 2, -60), Vector3(-15, 1, -85)]
		"frost_hairpin":
			length = 420.0
			anchors = [Vector3(-85, 2, -80), Vector3(0, 8, -105), Vector3(85, 15, -65), Vector3(95, 18, -10), Vector3(40, 14, 0), Vector3(15, 10, 35), Vector3(65, 5, 65), Vector3(25, 2, 105), Vector3(-65, 3, 85), Vector3(-100, 4, 10), Vector3(-50, 2, -20)]
		"magma_ring":
			length = 440.0
			anchors = [Vector3(-75, 3, -65), Vector3(-15, 5, -90), Vector3(65, 9, -65), Vector3(80, 8, 0), Vector3(45, 3, 70), Vector3(-25, 2, 85), Vector3(-80, 4, 45), Vector3(-60, 8, 18), Vector3(-18, 10, 30), Vector3(5, 8, -20), Vector3(-60, 5, -20)]
		"neon_spiral":
			length = 470.0
			anchors = [Vector3(55, 1, -90), Vector3(80, 4, -30), Vector3(45, 6, 20), Vector3(65, 2, 75), Vector3(5, 1, 95), Vector3(-55, 3, 65), Vector3(-40, 5, 10), Vector3(-70, 3, -40), Vector3(-30, 1, -95)]
		_:
			length = 500.0
			anchors = [Vector3(80, 2, -45), Vector3(85, 4, 35), Vector3(50, 7, 75), Vector3(-10, 5, 65), Vector3(-75, 3, 90), Vector3(-95, 2, 20), Vector3(-60, 1, -45), Vector3(-15, 3, -25), Vector3(20, 4, -75)]
	var curve := Curve3D.new()
	curve.bake_interval = 0.5
	for i in anchors.size() + 1:
		var index := i % anchors.size()
		var previous := anchors[(index + anchors.size() - 1) % anchors.size()]
		var next := anchors[(index + 1) % anchors.size()]
		var tangent := (next - previous) * 0.18
		curve.add_point(anchors[index], -tangent, tangent)
	var baked_length := curve.get_baked_length()
	var scale_xz := length / baked_length
	var result := PackedVector3Array()
	for i in 120:
		var point := curve.sample_baked(baked_length * float(i) / 120.0, true)
		point.x *= scale_xz
		point.z *= scale_xz
		if id in ["frost_hairpin", "magma_ring"]:
			point.y *= 0.6
		result.append(point)
	return result
