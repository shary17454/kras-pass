extends "res://src/arenas/natural_valley.gd"
## Natural battlefield; the road graph remains the AI's navigation contract.

var roads := AStar3D.new()
var buildings: Array[StaticBody3D] = []
var _variant := 0


func build(a: Arena) -> void:
	arena = a
	name = "TankWorld"
	_variant = ["tank_foundry", "tank_oasis", "tank_frost"].find(a.def.id)
	noise.seed = 72819 + _variant * 401
	noise.frequency = 0.026
	noise.fractal_octaves = 4
	_lighting()
	_load_meshes(ROOT + "rock_moss_set_01/rock_moss_set_01_2k.gltf", _rock_meshes)
	_load_meshes(ROOT + "pine_mobile.glb", _tree_meshes)
	_load_meshes(ROOT + "fern_02/fern_02_1k.gltf", _fern_meshes)
	# Replace the old tile and neon rim, retaining the arena's safety collision.
	for child in arena._static_root.find_children("*", "MeshInstance3D", true, false):
		child.visible = false
	for x in 5:
		for z in 5:
			var id := x * 5 + z
			roads.add_point(id, _bend(Vector3((x - 2) * 18, 0, (z - 2) * 18)))
			if x > 0:
				roads.connect_points(id, id - 5)
			if z > 0:
				roads.connect_points(id, id - 1)
	_terrain()
	var terrain := get_node("WoodlandTerrain") as MeshInstance3D
	var material := terrain.material_override as ShaderMaterial
	material.shader = load("res://src/arenas/battlefield_terrain.gdshader")
	for map in ["diff", "nor_gl", "rough"]:
		material.set_shader_parameter("road_" + map, load(ROOT + "gravel_floor/gravel_floor_" + map + "_2k.jpg"))
	var terrain_body := StaticBody3D.new()
	terrain_body.name = "TerrainCollision"
	var terrain_shape := CollisionShape3D.new()
	terrain_shape.shape = terrain.mesh.create_trimesh_shape()
	terrain_body.add_child(terrain_shape)
	add_child(terrain_body)
	for x in 4:
		for z in 4:
			_cover(x * 4 + z, _bend(Vector3(-27 + x * 18, 0.05, -27 + z * 18)))
	_vegetation()
	for side in [-1, 1]:
		for i in 10:
			_rock(i + 30, Vector3(side * 51, 0, -48 + i * 11), 3.8)
			_rock(i + 50, Vector3(-48 + i * 11, 0, side * 51), 3.8)
	_water()
	get_node("River").position = Vector3(-72, -2.5, 0)


func ground_height(x: float, z: float) -> float:
	var distance := minf(absf(fposmod(x - sin(z * 0.045) * 2 + 9, 18) - 9), absf(fposmod(z - sin(x * 0.05) * 2 + 9, 18) - 9))
	var outside := smoothstep(43, 80, maxf(absf(x), absf(z)))
	var interior := 0.02 + smoothstep(4.0, 8.0, distance) * (0.3 + absf(noise.get_noise_2d(x, z)) * 1.2)
	var mountains := 5.0 + noise.get_noise_2d(x, z) * 14.0
	mountains += smoothstep(65, 135, Vector2(x, z).length()) * 24.0
	var river := 1.0 - smoothstep(5, 15, absf(x + 72 + sin(z * 0.035) * 5))
	return lerpf(interior, mountains, outside) - river * 18.0


func _rock(index: int, p: Vector3, scale_value: float) -> void:
	var rock := MeshInstance3D.new()
	rock.mesh = _rock_meshes[posmod(index + _variant, _rock_meshes.size())]
	rock.position = Vector3(p.x, ground_height(p.x, p.z) - 0.5, p.z)
	rock.rotation.y = index * 2.4
	rock.scale = Vector3.ONE * scale_value
	add_child(rock)


func _cover(index: int, p: Vector3) -> void:
	var mesh := _rock_meshes[(index + _variant) % _rock_meshes.size()]
	var bounds := mesh.get_aabb()
	var scale_value := (7.2 + (index % 3) * 0.5) / maxf(bounds.size.x, bounds.size.z)
	var offset := -Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * scale_value
	var body := StaticBody3D.new()
	body.name = "RockCover%d" % index
	body.position = p
	body.rotation.y = float(index % 4) * PI * 0.5
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.position = offset
	visual.scale = Vector3.ONE * scale_value
	body.add_child(visual)
	var shape := CollisionShape3D.new()
	shape.shape = mesh.create_convex_shape()
	shape.position = offset
	shape.scale = Vector3.ONE * scale_value
	body.add_child(shape)
	add_child(body)
	buildings.append(body)


func _vegetation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8214 + _variant * 23
	var trees: Array[Transform3D] = []
	var ferns: Array[Transform3D] = []
	for i in 110:
		var p := Vector3(rng.randf_range(-110, 110), 0, rng.randf_range(-110, 110))
		if maxf(absf(p.x), absf(p.z)) < 48:
			continue
		p.y = ground_height(p.x, p.z)
		if p.y < -1.0:
			continue
		var s := rng.randf_range(9, 16)
		trees.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p))
	for x in 4:
		for z in 4:
			if x in [0, 3] and z in [0, 3]:
				var tree := _bend(Vector3(-27 + x * 18 + 4, 0, -27 + z * 18 - 4))
				tree.y = ground_height(tree.x, tree.z)
				trees.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * 12), tree))
				var trunk := StaticBody3D.new()
				var collider := CollisionShape3D.new()
				var capsule := CapsuleShape3D.new()
				capsule.height = 2.4
				capsule.radius = 0.2
				collider.shape = capsule
				trunk.position = tree + Vector3.UP * 1.2
				trunk.add_child(collider)
				add_child(trunk)
			for i in 6:
				var p := _bend(Vector3(-27 + x * 18 + rng.randf_range(-4.8, 4.8), 0, -27 + z * 18 + rng.randf_range(-4.8, 4.8)))
				p.y = ground_height(p.x, p.z)
				ferns.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.2, 2.2)), p))
	for variant in _tree_meshes.size():
		var group: Array[Transform3D] = []
		for i in range(variant, trees.size(), _tree_meshes.size()):
			group.append(trees[i])
		_instances(_tree_meshes[variant], group, "Pines%d" % variant)
	_instances(_fern_meshes[0], ferns, "Ferns")


func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	return roads.get_point_path(roads.get_closest_point(from), roads.get_closest_point(to))


func _bend(p: Vector3) -> Vector3:
	return p + Vector3(sin(p.z * 0.045) * 2, 0, sin(p.x * 0.05) * 2)
