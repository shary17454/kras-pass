extends Node3D
## One authored woodland course. Gameplay collision and checkpoints remain owned by Arena.

const ROOT := "res://assets/natural/"
var arena: Arena
var noise := FastNoiseLite.new()
var _rock_meshes: Array[Mesh] = []
var _tree_meshes: Array[Mesh] = []
var _fern_meshes: Array[Mesh] = []
var _road_material: StandardMaterial3D


func build(a: Arena) -> void:
	name = "FantasyWorld"
	arena = a
	noise.seed = 72819
	noise.frequency = 0.026
	noise.fractal_octaves = 4
	_lighting()
	_load_meshes(ROOT + "rock_moss_set_01/rock_moss_set_01_2k.gltf", _rock_meshes)
	_load_meshes(ROOT + "pine_mobile.glb", _tree_meshes)
	_load_meshes(ROOT + "fern_02/fern_02_1k.gltf", _fern_meshes)
	_road_material = pbr("gravel_floor", "2k", false)
	_terrain()
	_road()
	_dress()
	_water()


func _lighting() -> void:
	var env := arena._env.environment
	env.fog_enabled = true
	env.fog_density = 0.0009
	env.fog_light_color = Color("b6c8c5")
	env.fog_aerial_perspective = 0.35
	env.volumetric_fog_enabled = false
	env.ambient_light_energy = 0.55
	env.glow_enabled = false
	env.adjustment_saturation = 0.97
	env.tonemap_exposure = 1.1
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color = Color("668da8")
	sky.sky_horizon_color = Color("d1d8cf")
	sky.ground_horizon_color = Color("afbdb2")
	sky.ground_bottom_color = Color("3e504a")
	sky.sky_energy_multiplier = 0.85
	arena._light.rotation_degrees = Vector3(-32, -48, 0)
	arena._light.light_color = Color("fff2d7")
	arena._light.light_energy = 1.6
	arena._light.shadow_normal_bias = 0.45


func pbr(id: String, resolution: String, triplanar: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var path := ROOT + id + "/" + id
	mat.albedo_texture = load(path + "_diff_" + resolution + ".jpg")
	mat.normal_enabled = true
	mat.normal_texture = load(path + "_nor_gl_" + resolution + ".jpg")
	mat.normal_scale = 0.7
	mat.roughness_texture = load(path + "_rough_" + resolution + ".jpg")
	mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.uv1_triplanar = triplanar
	mat.uv1_world_triplanar = triplanar
	if triplanar:
		mat.uv1_scale = Vector3.ONE * 0.15
	return mat


func _nearest(x: float, z: float) -> Vector3:
	var best := INF
	var result := Vector3.ZERO
	for p in arena.circuit_line:
		var d := Vector2(x, z).distance_squared_to(Vector2(p.x, p.z))
		if d < best:
			best = d
			result = p
	return Vector3(sqrt(best), result.y, 0)


func ground_height(x: float, z: float) -> float:
	var nearest := _nearest(x, z)
	var distance := nearest.x
	var away := smoothstep(6, 34, distance)
	var ridge := 3 + noise.get_noise_2d(x, z) * 15
	var h := nearest.y - 0.5 + away * ridge
	h += smoothstep(55, 110, Vector2(x, z).length()) * (12 + noise.get_noise_2d(x + 240, z) * 36)
	# River gorge crosses beneath the elevated road twice.
	var river := 1.0 - smoothstep(5.0, 17.0, absf(x + sin(z * 0.035) * 5.0))
	h -= river * 12.0
	return h


func _terrain() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side := 151
	for z in side:
		for x in side:
			var px := float(x - 75) * 2
			var pz := float(z - 75) * 2
			surface.set_uv(Vector2(px, pz) * 0.12)
			surface.add_vertex(Vector3(px, ground_height(px, pz), pz))
	for z in side - 1:
		for x in side - 1:
			var i := z * side + x
			for index in [i, i + 1, i + side, i + 1, i + side + 1, i + side]:
				surface.add_index(index)
	surface.generate_normals()
	surface.generate_tangents()
	var terrain := MeshInstance3D.new()
	terrain.name = "WoodlandTerrain"
	terrain.mesh = surface.commit()
	var material := ShaderMaterial.new()
	material.shader = load("res://src/arenas/valley_terrain.gdshader")
	for id in ["forrest_ground_01", "aerial_rocks_01"]:
		var prefix := "ground" if id == "forrest_ground_01" else "rock"
		for map in ["diff", "nor_gl", "rough"]:
			material.set_shader_parameter(prefix + "_" + map, load(ROOT + id + "/" + id + "_" + map + "_2k.jpg"))
	terrain.material_override = material
	add_child(terrain)
	# A separate rocky ridge behind the road anchors the horizon at a believable scale.
	for i in 8:
		var angle := -0.5 + float(i) * 0.42
		var p := Vector3(cos(angle) * 85, 0, sin(angle) * 85)
		p.y = ground_height(p.x, p.z) - 4
		_rock(i, p, 9 + i % 4 * 2)


func _road() -> void:
	for body in arena._static_root.get_children():
		if body.has_meta("circuit_floor") or body.has_meta("circuit_wall"):
			for child in body.get_children():
				if child is MeshInstance3D:
					child.visible = false
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := arena.circuit_line
	var distance := 0.0
	for i in points.size() + 1:
		var idx := i % points.size()
		var p := points[idx]
		var direction := (points[(idx + 1) % points.size()] - points[(idx + points.size() - 1) % points.size()]).normalized()
		var across := Vector3(-direction.z, 0, direction.x).normalized()
		if i > 0:
			distance += p.distance_to(points[(idx + points.size() - 1) % points.size()])
		for sign_value in [-1, 1]:
			surface.set_uv(Vector2((sign_value + 1) * arena.track_width / 8, distance / 4))
			surface.add_vertex(p + across * sign_value * arena.track_width * 0.5 + Vector3.UP * 0.035)
	for i in points.size():
		var index := i * 2
		for j in [index, index + 2, index + 1, index + 1, index + 2, index + 3]:
			surface.add_index(j)
	surface.generate_normals()
	surface.generate_tangents()
	var road := MeshInstance3D.new()
	road.name = "GravelRoad"
	road.mesh = surface.commit()
	road.material_override = _road_material
	add_child(road)
	var rails: Array[Transform3D] = []
	for i in points.size():
		var next := points[(i + 1) % points.size()]
		var p := points[i]
		var d := (next - p).normalized()
		var across := Vector3(-d.z, 0, d.x).normalized()
		for sign_value in [-1, 1]:
			var edge: Vector3 = across * sign_value * (arena.track_width * 0.5 + 0.2)
			var b := Basis(d, across.cross(d), across)
			rails.append(Transform3D(Basis(b.x * p.distance_to(next) * 1.02, b.y * 0.16, b.z * 0.16), (p + next) * 0.5 + edge + Vector3.UP * 1.15))
			if i % 3 == 0:
				rails.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.22, 1.4, 0.22)), p + edge + Vector3.UP * 0.6))
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("796d59")
	wood.roughness = 0.88
	cube.material = wood
	_instances(cube, rails, "Guardrail")


func _load_meshes(path: String, output: Array[Mesh]) -> void:
	var packed: PackedScene = load(path)
	var instance := packed.instantiate()
	for child in instance.find_children("*", "MeshInstance3D", true, false):
		if child.mesh != null:
			output.append(child.mesh)
	instance.free()


func _rock(index: int, p: Vector3, scale_value: float) -> void:
	var rock := MeshInstance3D.new()
	rock.mesh = _rock_meshes[index % _rock_meshes.size()]
	var bounds := rock.mesh.get_aabb()
	var extent := maxf(Vector2(bounds.position.x, bounds.position.z).length(), Vector2(bounds.end.x, bounds.end.z).length()) * scale_value
	var closest := Vector3.ZERO
	var best := INF
	for point in arena.circuit_line:
		var distance := Vector2(point.x - p.x, point.z - p.z).length()
		if distance < best:
			best = distance
			closest = point
	var clearance := arena.track_width * 0.5 + extent + 1.5
	if best < clearance:
		var away := Vector3(p.x - closest.x, 0, p.z - closest.z).normalized()
		p = closest + away * clearance
		p.y = ground_height(p.x, p.z) - 0.3
	rock.position = p
	rock.rotation.y = float(index) * 2.4
	rock.scale = Vector3.ONE * scale_value
	add_child(rock)


func _dress() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9182
	var trees: Array[Transform3D] = []
	var ferns: Array[Transform3D] = []
	for i in 64:
		var p := arena.track_point(float(i) / 64.0)
		var radial := Vector3(p.x, 0, p.z).normalized()
		p += radial * (rng.randf_range(9, 18) if i % 3 != 0 else -rng.randf_range(10, 16))
		p.y = ground_height(p.x, p.z)
		if p.y < -4 or _nearest(p.x, p.z).x < arena.track_width * 0.5 + 2:
			continue
		if i % 3 == 0:
			_rock(i, p - Vector3.UP * 0.3, rng.randf_range(1.5, 3.8))
		if i % 2 == 0:
			var scale_value := rng.randf_range(8.0, 13.0)
			trees.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scale_value), p))
		for j in 3:
			var f := p + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))
			f.y = ground_height(f.x, f.z)
			ferns.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.5)), f))
	for variant in _tree_meshes.size():
		var group: Array[Transform3D] = []
		for i in range(variant, trees.size(), _tree_meshes.size()):
			group.append(trees[i])
		_instances(_tree_meshes[variant], group, "Pines%d" % variant)
	for mesh in _fern_meshes.slice(0, 1):
		_instances(mesh, ferns, "Ferns")


func _instances(mesh: Mesh, transforms: Array[Transform3D], label: String) -> void:
	var node := MultiMeshInstance3D.new()
	node.name = label
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	node.multimesh = multimesh
	add_child(node)


func _water() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(20, 300)
	mesh.subdivide_width = 16
	mesh.subdivide_depth = 80
	var river := MeshInstance3D.new()
	river.name = "River"
	river.mesh = mesh
	river.position.y = -6.0
	var material := ShaderMaterial.new()
	material.shader = load("res://src/arenas/valley_water.gdshader")
	river.material_override = material
	add_child(river)
