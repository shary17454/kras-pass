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

func use_presentation_only() -> void:
	if not is_instance_valid(_body):
		return
	_mesh.reparent(self)
	_body.collision_layer = 0
	_body.queue_free()
	_body = null
	_shape = null

func apply_snapshot(next_radius: float, next_holes: Array) -> void:
	var value := maxf(RADIUS_STEP, floorf(next_radius / RADIUS_STEP) * RADIUS_STEP)
	if is_equal_approx(radius, value) and holes == next_holes:
		return
	radius = value
	holes = next_holes.duplicate(true)
	_rebuild()

func edge_distance(point: Vector3) -> float:
	var flat := Vector2(point.x, point.z)
	var distance := radius - flat.length()
	for hole in holes:
		distance = minf(distance, flat.distance_to(hole.point) - float(hole.radius))
	return distance

func has_ground(point: Vector3, margin := 0.0) -> bool:
	return edge_distance(point) >= margin

func path_clear(from: Vector3, to: Vector3, margin := 0.42) -> bool:
	if not has_ground(from, margin) or not has_ground(to, margin):
		return false
	var start := Vector2(from.x, from.z)
	var end := Vector2(to.x, to.z)
	var segment := end - start
	for hole in holes:
		var fraction := 0.0
		if segment.length_squared() > 0.0001:
			fraction = clampf((hole.point - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
		if (start + segment * fraction).distance_to(hole.point) < float(hole.radius) + margin:
			return false
	return true

func steering_direction(from: Vector3, target: Vector3, lookahead := 1.2, margin := 0.5) -> Vector3:
	var to := target - from
	to.y = 0.0
	if to.length() < 0.15 or lookahead <= 0.0:
		return Vector3.ZERO
	var distance := minf(lookahead, to.length())
	var best := Vector3.ZERO
	var cost := INF
	var clearance := edge_distance(from)
	for step in 32:
		var angle := TAU * float(step) / 32.0
		var direction := Vector3(cos(angle), 0, sin(angle))
		var next := from + direction * distance
		var safe := path_clear(from, next, margin)
		# Near a rim, allow only escape steps that never lose body clearance.
		if not safe and clearance >= 0.0 and clearance < margin:
			safe = has_ground(next, margin)
			for sample in range(1, 9):
				if edge_distance(from.lerp(next, float(sample) / 8.0)) + 0.0001 < clearance:
					safe = false
					break
		if not safe:
			continue
		var next_cost := next.distance_squared_to(target)
		if next_cost < cost:
			cost = next_cost
			best = direction
	return best


func retreat_point(point: Vector3) -> Vector3:
	var margin := minf(3.0, radius * 0.25)
	if has_ground(point, margin):
		return point
	var best := point
	var nearest := INF
	var on_ground := has_ground(point, 0.42)
	# Sample local escape routes instead of steering through a carved center.
	for distance in [0.5, 1.0, 2.0, 4.0, 8.0, 16.0, 32.0]:
		for step in 32:
			var angle := TAU * float(step) / 32.0
			var candidate := point + Vector3(cos(angle), 0, sin(angle)) * float(distance)
			if not has_ground(candidate, margin):
				continue
			if on_ground and not path_clear(point, candidate):
				continue
			var cost := point.distance_squared_to(candidate)
			if cost < nearest:
				nearest = cost
				best = candidate
		if nearest < INF:
			break
	return best

func _rebuild() -> void:
	var cuts: Array[PackedVector2Array] = []
	var cut_bounds: Array[Rect2] = []
	for hole in holes:
		var circle := PackedVector2Array()
		for step in 48:
			var angle := TAU * float(step) / 48.0
			circle.append(hole.point + Vector2(cos(angle), sin(angle)) * float(hole.radius))
		cuts.append(circle)
		var extent := Vector2.ONE * float(hole.radius)
		cut_bounds.append(Rect2(hole.point - extent, extent * 2.0))
	var vertices := PackedVector3Array()
	for sector in SECTORS:
		var a := TAU * float(sector) / SECTORS
		var b := TAU * float(sector + 1) / SECTORS
		var triangle := PackedVector2Array([Vector2.ZERO,
			Vector2(cos(a), sin(a)) * radius, Vector2(cos(b), sin(b)) * radius])
		var bounds := Rect2(Vector2.ZERO, Vector2.ZERO).expand(triangle[1]).expand(triangle[2])
		var pieces: Array[PackedVector2Array] = [triangle]
		for cut_index in cuts.size():
			# Every remaining piece lies inside this sector; disjoint bounds cannot cut it.
			if not _cut_overlaps_sector(bounds, cut_bounds[cut_index]):
				continue
			var cut := cuts[cut_index]
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
	if is_instance_valid(_shape):
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


func _cut_overlaps_sector(sector: Rect2, cut: Rect2) -> bool:
	# Keep tangencies and near-boundary polygon rounding on the exact clipping path.
	return sector.grow(0.001).intersects(cut, true)
