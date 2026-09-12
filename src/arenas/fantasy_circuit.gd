extends Node3D


func build(arena: Arena) -> void:
	name = "FantasyWorld"
	var id := arena.def.id
	var ice := id == "frost_hairpin"
	var lava := id == "magma_ring"
	var sky := id == "sky_causeway"
	var neon := id == "neon_spiral"
	var stone := Color("abcbd6") if ice else Color("6f8089")
	if lava:
		stone = Color("544e60")
	if sky:
		stone = Color("ac98bb")
	var accent := arena.def.accent_color
	var env := arena._env.environment
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	var sky_mat := env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = Color("275ab2") if not lava else Color("45245d")
	sky_mat.sky_horizon_color = Color("efb6cc") if sky else Color("94d9e6")
	if lava:
		sky_mat.sky_horizon_color = Color("ed966e")
	# Large silhouettes sit clear of the racing corridor and are deterministic.
	for i in 14:
		var angle := TAU * i / 14.0
		var p := Vector3(cos(angle), 0, sin(angle)) * (arena.def.radius * 1.7 + 14 + i % 4 * 6)
		var island := Node3D.new()
		island.position = p + Vector3.DOWN * (7 if sky else 5)
		add_child(island)
		var rock := sculpted_rock(i, stone)
		rock.scale = Vector3(6 + i % 4, 12 + i % 5 * 2, 7 + i % 3)
		island.add_child(rock)
		if i % 3 == 0:
			var tower := MeshFactory.cylinder(1.1, 10, stone.lightened(0.18), 0, 12)
			tower.position = Vector3(0, 15, 0)
			island.add_child(tower)
			var roof := MeshFactory.cone(2.4, 4, accent)
			roof.position = Vector3(0, 22, 0)
			island.add_child(roof)
	# Repeated arches frame the road; posts remain outside collision barriers.
	for i in 6:
		var t := float(i) / 6.0
		var p := arena.track_point(t)
		var forward := (arena.track_point(t + 0.016) - p).normalized()
		var frame := Node3D.new()
		frame.position = p
		frame.rotation.y = atan2(forward.x, forward.z)
		add_child(frame)
		var half := arena.track_width * 0.5 + 1.4
		for sign_value in [-1, 1]:
			var post := MeshFactory.cylinder(0.65, 7, stone.lightened(0.18), 0, 12)
			post.position = Vector3(sign_value * half, 3.5, 0)
			frame.add_child(post)
			var cap := MeshFactory.sphere(0.85, accent, 0.3)
			cap.position = Vector3(sign_value * half, 7.2, 0)
			frame.add_child(cap)
		for part in 9:
			var a := PI * part / 9.0
			var b := PI * (part + 1) / 9.0
			var start := Vector3(cos(a) * half, 6 + sin(a) * 2.5, 0)
			var end := Vector3(cos(b) * half, 6 + sin(b) * 2.5, 0)
			var beam := solid(Vector3(start.distance_to(end) * 1.08, 0.45, 0.8), accent)
			beam.position = (start + end) * 0.5
			beam.rotation.z = atan2(end.y - start.y, end.x - start.x)
			frame.add_child(beam)
	for i in range(0, arena.circuit_line.size(), 6):
		var p: Vector3 = arena.circuit_line[i]
		var pillar := MeshFactory.cylinder(1.1, 16 + p.y, stone, 0, 10)
		pillar.position = Vector3(p.x, p.y * 0.5 - 8.5, p.z)
		add_child(pillar)
	var basin := MeshFactory.cylinder(240, 1, Color("277f9e") if not lava else Color("f37342"), 0.15 if lava else 0.0, 64)
	basin.position.y = -19
	add_child(basin)
	if sky or ice:
		for i in 12:
			var cloud := MeshFactory.sphere(1, Color("e9e8f5"))
			cloud.scale = Vector3(14, 2.2, 8)
			cloud.position = Vector3(cos(i * 2.1) * 65, -9 - i % 3, sin(i * 2.1) * 65)
			add_child(cloud)
	if neon:
		for i in 10:
			var spire := MeshFactory.cylinder(1.5, 12 + i % 4 * 4, Color("395d74"), 0, 6)
			spire.position = Vector3(cos(i * TAU / 10) * 10, 2, sin(i * TAU / 10) * 10)
			add_child(spire)
	if lava:
		var volcano := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 3.0
		cone.bottom_radius = 9.0
		cone.height = 15
		cone.radial_segments = 24
		volcano.mesh = cone
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("4e424f")
		volcano.material_override = mat
		volcano.position.y = -2
		add_child(volcano)
		var crater := MeshFactory.cylinder(2.8, 0.15, Color("ffb357"), 1.4, 24)
		crater.position.y = 5.55
		add_child(crater)
	elif ice:
		for i in 7:
			var crystal := MeshFactory.cone(2.2, 13 + i % 3 * 4, Color("98daef"))
			crystal.position = Vector3(cos(i * 2.4) * 6, 1, sin(i * 2.4) * 6)
			crystal.rotation.z = sin(i) * 0.25
			add_child(crystal)
	elif sky:
		var pedestal := MeshFactory.cylinder(8, 2, Color("e4d4ca"), 0, 24)
		pedestal.position.y = -4
		add_child(pedestal)
		for i in 8:
			var column := MeshFactory.cylinder(0.65, 10, Color("e4d4ca"), 0, 16)
			column.position = Vector3(cos(i * TAU / 8) * 6, 2, sin(i * TAU / 8) * 6)
			add_child(column)
		var dome := MeshFactory.sphere(7.2, Color("77baad"))
		dome.scale.y = 0.4
		dome.position.y = 7
		add_child(dome)


func solid(size: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.65
	node.material_override = mat
	return node


func sculpted_rock(seed_value: int, color: Color) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = 1
	sphere.height = 2
	sphere.radial_segments = 28
	sphere.rings = 18
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = seed_value + 834
	noise.frequency = 2.4
	for i in vertices.size():
		var v := vertices[i]
		var displacement := 1.0 + noise.get_noise_3dv(v) * 0.3
		vertices[i] = Vector3(v.x * displacement, v.y, v.z * displacement)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := SurfaceTool.new()
	surface.create_from(mesh, 0)
	surface.generate_normals()
	var node := MeshInstance3D.new()
	node.mesh = surface.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	node.material_override = mat
	return node
