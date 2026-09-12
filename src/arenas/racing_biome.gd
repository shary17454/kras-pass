extends "res://src/arenas/natural_valley.gd"
## Shared road geometry and assets; each course owns its terrain and weather.

var biome := 0
var weather: Node3D
const VOLCANO := Vector2(-135, -100)


func build(a: Arena) -> void:
	biome = {"dune_circuit": 1, "frost_hairpin": 2, "magma_ring": 3, "neon_spiral": 4, "alula_rain": 5}.get(a.def.id, 0)
	super.build(a)
	set_meta("biome", biome)
	var terrain := get_node("WoodlandTerrain") as MeshInstance3D
	var material := terrain.material_override as ShaderMaterial
	material.set_shader_parameter("biome", biome)
	if biome in [1, 2, 3]:
		for child in get_children():
			if child is MeshInstance3D and child.name not in ["WoodlandTerrain", "GravelRoad", "River", "Lava", "LavaFlow"]:
				child.material_override = material
	var asphalt := ShaderMaterial.new()
	asphalt.shader = load("res://src/arenas/racing_asphalt.gdshader")
	asphalt.set_shader_parameter("aggregate", _road_material.albedo_texture)
	asphalt.set_shader_parameter("surface_normal", _road_material.normal_texture)
	asphalt.set_shader_parameter("road_width", arena.track_width)
	asphalt.set_shader_parameter("wet", biome in [4, 5])
	get_node("GravelRoad").material_override = asphalt
	if biome in [2, 3, 4, 5]:
		weather = load("res://src/arenas/racing_weather.gd").new()
		add_child(weather)
		weather.build(arena, 4 if biome == 5 else biome, Vector3(VOLCANO.x, 32, VOLCANO.y))


func river_center_x() -> float:
	return 110.0 if biome == 4 else -125.0


func vegetation_samples() -> int:
	return 160 if biome == 0 else (100 if biome == 4 else 52)


func ground_height(x: float, z: float) -> float:
	var nearest := _nearest(x, z)
	var shoulder := smoothstep(arena.track_width * 0.5 + 6.0, 38.0, nearest.x)
	var h := nearest.y - 0.08
	if biome == 1:
		var dunes := 8.0 + sin(x * 0.034 + sin(z * 0.018)) * 11.0 + sin(z * 0.04) * 5.0
		return h + dunes * shoulder
	if biome == 2:
		var peaks := 60.0 * exp(-pow((x + 140) / 42.0, 2)) + 35.0 * exp(-pow((z - 130) / 50.0, 2))
		var glacier := sin(z * 0.018) * 5.0 + noise.get_noise_2d(x, z) * 4.0
		return h + (peaks + glacier) * shoulder
	if biome in [0, 4]:
		var hills := 5.0 + sin(x * 0.018) * cos(z * 0.015) * (10.0 if biome == 0 else 22.0)
		var channel := absf(x - river_center_x() + sin(z * 0.035) * 5.0)
		var gorge := (1.0 - smoothstep(6.0, 20.0, channel)) * (24.0 if biome == 4 else 15.0)
		return h + (hills - gorge) * shoulder
	var r := Vector2(x, z).distance_to(VOLCANO)
	var cone := 2.0 + 40.0 * exp(-r * r / 800.0) - 13.0 * exp(-r * r / 50.0)
	var basalt := noise.get_noise_2d(x, z) * 5.0
	return h + shoulder * (cone + basalt * smoothstep(18.0, 40.0, r))


func _add_distant_rocks() -> void:
	if biome == 0 or biome == 3:
		return
	var count := 5 if biome == 1 else 9
	for i in count:
		var p := Vector3(145 if biome == 4 else -145, 0, -150 + i * 38)
		p.y = ground_height(p.x, p.z) - 3.0
		_rock(i, p, 3.0 + float(i % 3) * 1.5)


func _lighting() -> void:
	super._lighting()
	var env := arena._env.environment
	var sky := env.sky.sky_material as ProceduralSkyMaterial
	if biome == 1:
		sky.sky_top_color = Color("468fba")
		sky.sky_horizon_color = Color("e4d2ac")
		env.fog_light_color = Color("ddc498")
		arena._light.light_energy = 1.8
	elif biome == 2:
		sky.sky_top_color = Color("829eae")
		sky.sky_horizon_color = Color("d8e5eb")
		env.fog_light_color = Color("c5dce7")
		env.fog_density = 0.002
		arena._light.light_color = Color("e6f4ff")
	elif biome == 3:
		sky.sky_top_color = Color("33313a")
		sky.sky_horizon_color = Color("927b72")
		env.fog_light_color = Color("796b67")
		env.fog_density = 0.0018
		arena._light.light_color = Color("ffd9b8")
		arena._light.light_energy = 1.25
	elif biome == 4:
		sky.sky_top_color = Color("414c58")
		sky.sky_horizon_color = Color("96a4a9")
		env.fog_light_color = Color("86979e")
		env.fog_density = 0.002
		arena._light.light_color = Color("c5dce5")
		arena._light.light_energy = 0.95
		env.ambient_light_energy = 0.7


func _dress() -> void:
	if biome in [0, 4]:
		_forest()
		return
	if biome == 2:
		super._dress()
		return
	# Sparse rock outcrops leave the dunes and lava fields open, without pines.
	for i in 20:
		var angle := float(i) * 2.399
		var distance := 45.0 + float(i % 4) * 12.0
		var p := Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		p.y = ground_height(p.x, p.z) - 0.5
		_rock(i, p, 1.0 + float(i % 3) * 0.6)


func _forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8710 + biome
	var trees: Array[Transform3D] = []
	var ferns: Array[Transform3D] = []
	for z in 18:
		for x in 18:
			if rng.randf() > (0.75 if biome == 0 else 0.55):
				continue
			var p := Vector3((x - 9) * 16.0 + rng.randf_range(-5, 5), 0, (z - 9) * 16.0 + rng.randf_range(-5, 5))
			p.y = ground_height(p.x, p.z)
			if p.y < -3 or _nearest(p.x, p.z).x < arena.track_width * 0.5 + 12:
				continue
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(10, 16))
			trees.append(Transform3D(basis, p))
			for j in 2:
				var f := p + Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-4, 4))
				f.y = ground_height(f.x, f.z)
				ferns.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU), f))
	for variant in _tree_meshes.size():
		var group: Array[Transform3D] = []
		for i in range(variant, trees.size(), _tree_meshes.size()):
			group.append(trees[i])
		_instances(_tree_meshes[variant], group, "Pines%d" % variant)
	_instances(_fern_meshes[0], ferns, "Ferns")


func _water() -> void:
	if biome == 1:
		return
	if biome != 3:
		super._water()
		return
	var lava := MeshInstance3D.new()
	lava.name = "Lava"
	var disc := CylinderMesh.new()
	disc.top_radius = 8.0
	disc.bottom_radius = 8.0
	disc.height = 0.1
	disc.radial_segments = 64
	lava.mesh = disc
	lava.position = Vector3(VOLCANO.x, ground_height(VOLCANO.x, VOLCANO.y) + 2.0, VOLCANO.y)
	var material := ShaderMaterial.new()
	material.shader = load("res://src/arenas/racing_lava.gdshader")
	lava.material_override = material
	add_child(lava)
	# Flowing lava remains away from the open racing road.
	var flow := MeshInstance3D.new()
	flow.name = "LavaFlow"
	var ribbon := SurfaceTool.new()
	ribbon.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 24:
		var z := VOLCANO.y + 7.0 + i * 1.1
		var x := VOLCANO.x + sin(i * 0.15) * 3.0
		for side in [-1.0, 1.0]:
			var px: float = x + side * 1.5
			ribbon.add_vertex(Vector3(px, ground_height(px, z) + 0.12, z))
	for i in 23:
		var j := i * 2
		for index in [j, j + 1, j + 2, j + 1, j + 3, j + 2]:
			ribbon.add_index(index)
	ribbon.generate_normals()
	flow.mesh = ribbon.commit()
	flow.material_override = material
	add_child(flow)
