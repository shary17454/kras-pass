extends Node3D
## Thin sectors let Geometry2D carve circular cuts without interior-hole polygons.
const SECTORS := 128
const RADIUS_STEP := 0.125
var radius := 16.0
var thickness := 1.0
var holes: Array = []
var _body: StaticBody3D
var _shape: CollisionShape3D
var _mesh: MeshInstance3D

func build(initial_radius: float, depth: float, material: Material) -> void:
	radius = initial_radius
	thickness = depth
	_body = StaticBody3D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)
	_mesh = MeshInstance3D.new()
	_mesh.material_override = material
	_body.add_child(_mesh)
	_shape = CollisionShape3D.new()
	_body.add_child(_shape)
	_rebuild()

func set_radius(value: float) -> void:
	var next := maxf(RADIUS_STEP, floorf(value / RADIUS_STEP) * RADIUS_STEP)
	if not is_equal_approx(radius, next):
		radius = next
		_rebuild()

func open_hole(point: Vector3, size: float) -> void:
	# Authored Colossus craters are radius 3; smaller cuts need finer sectors.
	if size < 0.75:
		return
	holes.append({"point": Vector2(point.x, point.z), "radius": size})
	_rebuild()

func reset() -> void:
	holes.clear()
	_rebuild()

func edge_distance(point: Vector3) -> float:
	var flat := Vector2(point.x, point.z)
	var distance := radius - flat.length()
	for hole in holes:
		distance = minf(distance, flat.distance_to(hole.point) - float(hole.radius))
	return distance

func has_ground(point: Vector3, margin := 0.0) -> bool:
	return edge_distance(point) >= margin

func _rebuild() -> void:
	var cuts: Array[PackedVector2Array] = []
	for hole in holes:
		var circle := PackedVector2Array()
		for step in 48:
			var angle := TAU * float(step) / 48.0
			circle.append(hole.point + Vector2(cos(angle), sin(angle)) * float(hole.radius))
		cuts.append(circle)
	var vertices := PackedVector3Array()
	for sector in SECTORS:
		var a := TAU * float(sector) / SECTORS
		var b := TAU * float(sector + 1) / SECTORS
		var pieces: Array[PackedVector2Array] = [PackedVector2Array([Vector2.ZERO,
			Vector2(cos(a), sin(a)) * radius, Vector2(cos(b), sin(b)) * radius])]
		for cut in cuts:
			var remaining: Array[PackedVector2Array] = []
			for piece in pieces:
				remaining.append_array(Geometry2D.clip_polygons(piece, cut))
			pieces = remaining
		for piece in pieces:
			var triangles := Geometry2D.triangulate_polygon(piece)
			for index in range(0, triangles.size(), 3):
				var points: Array[Vector3] = []
				for corner in 3:
					var point: Vector2 = piece[triangles[index + corner]]
					points.append(Vector3(point.x, 0, point.y))
				if (points[1] - points[0]).cross(points[2] - points[0]).y < 0:
					var swap := points[1]
					points[1] = points[2]
					points[2] = swap
				vertices.append_array(PackedVector3Array(points))
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(vertices)
	_shape.shape = shape
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		for vertex in vertices:
			normals.append(Vector3.UP)
			uvs.append(Vector2(vertex.x, vertex.z) * 0.1)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh.mesh = mesh
