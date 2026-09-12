extends "res://src/arenas/racing_biome.gd"
## Two original race environments sharing only natural materials and prop builders.
var coast := false
var stone: StandardMaterial3D
var timber: StandardMaterial3D


func build(a: Arena) -> void:
	coast = a.def.id == "sinbad_coast"
	super.build(a)
	set_meta("biome", 6 if coast else 7)
	get_node("WoodlandTerrain").material_override.set_shader_parameter("biome", 6 if coast else 7)


func ground_height(x: float, z: float) -> float:
	var nearest := _nearest(x, z)
	var shoulder := smoothstep(arena.track_width * 0.5 + 9.0, 38.0, nearest.x)
	var h := nearest.y - 0.08
	if coast:
		return h + shoulder * (-10.0 + noise.get_noise_2d(x, z) * 3.0)
	var dunes := 3.0 + sin(x * 0.025) * cos(z * 0.021) * 5.0
	var channel := (1.0 - smoothstep(9.0, 25.0, absf(x - 145.0))) * 18.0
	return h + shoulder * (dunes - channel)


func _lighting() -> void:
	super._lighting()
	var env := arena._env.environment
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color = Color("387fa8") if coast else Color("6f9cac")
	sky.sky_horizon_color = Color("c4e0e3") if coast else Color("e5d4af")
	env.fog_density = 0.0005
	env.fog_light_color = sky.sky_horizon_color
	env.ambient_light_energy = 0.45
	arena._light.light_color = Color("fff2d2")
	arena._light.rotation_degrees = Vector3(-38, -65, 0)
	arena._light.light_energy = 1.7


func _add_distant_rocks() -> void:
	pass


func _water() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(650, 650) if coast else Vector2(28, 620)
	var water := MeshInstance3D.new()
	water.name = "Ocean" if coast else "River"
	water.mesh = mesh
	water.position = Vector3(0 if coast else 145, -3.0, 0)
	var material := ShaderMaterial.new()
	material.shader = load("res://src/arenas/valley_water.gdshader")
	water.material_override = material
	add_child(water)


func _safe_site(p: Vector3, radius: float) -> Vector3:
	var result := p
	for attempt in 12:
		var closest := Vector3.ZERO
		var distance := INF
		for point in arena.circuit_line:
			var d := Vector2(point.x - result.x, point.z - result.z).length()
			if d < distance:
				distance = d
				closest = point
		var required := arena.track_width * 0.5 + radius + 12.0
		if distance >= required:
			break
		var away := Vector3(result.x - closest.x, 0, result.z - closest.z).normalized()
		if away.length_squared() < 0.1:
			away = Vector3.LEFT
		result = closest + away * required
	result.y = ground_height(result.x, result.z)
	return result


func _dress() -> void:
	stone = pbr("aerial_rocks_01", "2k", true)
	stone.albedo_color = Color("e1c098")
	stone.normal_scale = 0.5
	timber = MeshFactory.satin(Color("55351f"), 0.85)
	var root := Node3D.new()
	root.name = "SinbadHarbour" if coast else "PharaohMonuments"
	add_child(root)
	if coast:
		for i in 5:
			var p := _safe_site(Vector3(-130 + i * 55, 0, -160), 22)
			_rock(i, p, 12.0 + i * 1.5)
		for i in 3:
			var p := _safe_site(Vector3(-45 + i * 45, 0, 5 - i * 35), 14)
			p.y = -3.0
			_ship(root, p, 0.8 + i * 0.2, i * 1.3)
		var port := _safe_site(Vector3(-130, 0, 105), 24)
		_port(root, port)
	else:
		for i in 3:
			var p := _safe_site(Vector3(-140 - i * 18, 0, -120 + i * 85), 42)
			_pyramid(root, p, 68.0 - i * 12.0, 43.0 - i * 6.0)
		_temple(root, _safe_site(Vector3(-15, 0, 30), 22))
	for i in 32:
		var t := float(i) / 32.0
		var p := arena.track_point(t)
		var ahead := arena.track_point(t + 0.005)
		var across := Vector3(-(ahead - p).z, 0, (ahead - p).x).normalized()
		p += across * (arena.track_width * 0.5 + 11.0) * (-1.0 if i % 2 else 1.0)
		if _nearest(p.x, p.z).x < arena.track_width * 0.5 + 6.0:
			continue
		p.y = ground_height(p.x, p.z)
		if p.y > -2.2:
			_palm(root, p, 7.0 + (i % 4) * 1.3)


func _piece(parent: Node3D, mesh: Mesh, p: Vector3, material: Material, solid := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = p
	node.material_override = material
	parent.add_child(node)
	if solid:
		var body := StaticBody3D.new()
		body.position = p
		var collision := CollisionShape3D.new()
		collision.shape = mesh.create_trimesh_shape()
		body.add_child(collision)
		parent.add_child(body)
	return node


func _block(parent: Node3D, p: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_piece(parent, mesh, p, material, true)


func _pyramid(parent: Node3D, p: Vector3, width: float, height: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in 48:
		var y0 := float(level) / 48.0
		var y1 := float(level + 1) / 48.0
		var r0 := width * 0.5 * (1.0 - y0)
		var r1 := width * 0.5 * (1.0 - y1)
		for side in 4:
			var a := Vector3(cos(PI * 0.25 + side * PI * 0.5), 0, sin(PI * 0.25 + side * PI * 0.5)) * 1.4142
			var b := Vector3(cos(PI * 0.25 + (side + 1) * PI * 0.5), 0, sin(PI * 0.25 + (side + 1) * PI * 0.5)) * 1.4142
			for v in [a * r0 + Vector3.UP * y0 * height, a * r1 + Vector3.UP * y1 * height, b * r0 + Vector3.UP * y0 * height, b * r0 + Vector3.UP * y0 * height, a * r1 + Vector3.UP * y1 * height, b * r1 + Vector3.UP * y1 * height]:
				surface.set_uv(Vector2(v.x + v.z, v.y) * 0.2)
				surface.add_vertex(v)
	surface.generate_normals()
	_piece(parent, surface.commit(), p, stone, true).name = "Pyramid"


func _temple(parent: Node3D, p: Vector3) -> void:
	_block(parent, p + Vector3(0, 0.6, 0), Vector3(28, 1.2, 32), stone)
	for side in [-1, 1]:
		for row in 5:
			var column := CylinderMesh.new()
			column.top_radius = 1.1
			column.bottom_radius = 1.4
			column.height = 12
			column.radial_segments = 20
			var at := p + Vector3(side * 10, 7.2, row * 6 - 12)
			_piece(parent, column, at, stone, true)
			_block(parent, at + Vector3.UP * 6.1, Vector3(3.7, 1.1, 3.7), stone)
		_block(parent, p + Vector3(side * 10, 14, 0), Vector3(4, 1.6, 32), stone)
	for side in [-1, 1]:
		_block(parent, p + Vector3(side * 8, 9, -21), Vector3(9, 18, 5), stone)
	_block(parent, p + Vector3(0, 18, -21), Vector3(25, 2, 5), stone)


func _palm(parent: Node3D, p: Vector3, height: float) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.16
	trunk.bottom_radius = 0.34
	trunk.height = height
	trunk.radial_segments = 9
	_piece(parent, trunk, p + Vector3.UP * height * 0.5, timber)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for leaf in 9:
		var direction := Vector3(cos(leaf * TAU / 9.0), 0, sin(leaf * TAU / 9.0))
		var across := Vector3(-direction.z, 0, direction.x)
		for segment in 7:
			var t := float(segment) / 7
			var u := float(segment + 1) / 7
			var a := direction * t * 4.5 + Vector3.UP * (sin(t * PI) * 1.2 - t * 1.4)
			var b := direction * u * 4.5 + Vector3.UP * (sin(u * PI) * 1.2 - u * 1.4)
			var wa := sin(t * PI) * 0.55
			var wb := sin(u * PI) * 0.55
			for v in [a - across * wa, b - across * wb, a + across * wa, a + across * wa, b - across * wb, b + across * wb]:
				surface.add_vertex(v)
	surface.generate_normals()
	var leaves := MeshFactory.satin(Color("347541"), 0.85).duplicate() as StandardMaterial3D
	leaves.cull_mode = BaseMaterial3D.CULL_DISABLED
	_piece(parent, surface.commit(), p + Vector3.UP * height, leaves)


func _ship(parent: Node3D, p: Vector3, scale_value: float, yaw: float) -> void:
	var ship := Node3D.new()
	ship.name = "Dhow"
	ship.position = p
	ship.rotation.y = yaw
	ship.scale = Vector3.ONE * scale_value
	parent.add_child(ship)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 24:
		var t := float(i) / 24
		var u := float(i + 1) / 24
		var a := Vector3(sin(t * PI) * 3.6, 1.2 + pow(absf(t - 0.5) * 2, 3) * 1.8, t * 20 - 10)
		var b := Vector3(sin(u * PI) * 3.6, 1.2 + pow(absf(u - 0.5) * 2, 3) * 1.8, u * 20 - 10)
		for side in [-1, 1]:
			var x := a * Vector3(side, 1, 1)
			var y := b * Vector3(side, 1, 1)
			var keel_a := Vector3(0, -1.0, a.z)
			var keel_b := Vector3(0, -1.0, b.z)
			for v in [x, y, keel_a, keel_a, y, keel_b]:
				surface.add_vertex(v)
	surface.generate_normals()
	var wood := timber.duplicate() as StandardMaterial3D
	wood.cull_mode = BaseMaterial3D.CULL_DISABLED
	_piece(ship, surface.commit(), Vector3.ZERO, wood)
	_block(ship, Vector3(0, 1.1, 0), Vector3(5, 0.3, 13), timber)
	var mast := CylinderMesh.new()
	mast.top_radius = 0.12
	mast.bottom_radius = 0.22
	mast.height = 16
	_piece(ship, mast, Vector3(0, 9, 0), timber)
	var sail := SurfaceTool.new()
	sail.begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [Vector3(0, 17, -1), Vector3(0, 3, -7), Vector3(1.8, 4, 9)]:
		sail.add_vertex(v)
	sail.generate_normals()
	var cloth := MeshFactory.satin(Color("e5ded0"), 0.95).duplicate() as StandardMaterial3D
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	_piece(ship, sail.commit(), Vector3.ZERO, cloth)


func _port(parent: Node3D, p: Vector3) -> void:
	for i in 4:
		var at := p + Vector3(i * 9 - 14, 0, 0)
		_block(parent, at + Vector3(0, 4, 0), Vector3(7, 8, 8), stone)
		var dome := SphereMesh.new()
		dome.radius = 3.5
		dome.height = 7
		dome.radial_segments = 20
		dome.rings = 10
		_piece(parent, dome, at + Vector3(0, 7.8, 0), stone)
	_block(parent, p + Vector3(0, 1, 12), Vector3(38, 1, 10), timber)
