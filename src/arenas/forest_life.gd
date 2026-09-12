extends Node3D
## Bounded decorative wildlife: no collision, race RNG, or unbounded spawning.
const CYCLE := 24.0
var elapsed := 0.0
var world: Node3D
var groups: Array[Dictionary] = []
var water_materials: Array[ShaderMaterial] = []
var sites: Array[Vector3] = []

func build(scenery: Node3D) -> void:
	name = "ForestLife"
	world = scenery
	for seed_index in [44, 100]:
		var site := _site(seed_index)
		sites.append(site)
		_waterfall(site)
		var animals: Array[Node3D] = []
		for i in 4:
			var animal := load("res://src/arenas/forest_animal.gd").new() as Node3D
			add_child(animal)
			animal.build(i == 0)
			animals.append(animal)
		var path: Array[Vector3] = []
		for i in 64:
			var p := site + Vector3(cos(i * TAU / 64) * 7.0, 0, sin(i * TAU / 64) * 5.0)
			p.y = world.ground_height(p.x, p.z) - preload("res://src/arenas/race_structures.gd").excavation(world.arena, p)
			path.append(p)
		groups.append({"animals": animals, "path": path})
	advance(0.0)

func _site(seed_index: int) -> Vector3:
	for offset in 120:
		var index := (seed_index + offset) % 120
		var p: Vector3 = world.arena.circuit_line[index]
		var forward: Vector3 = (world.arena.circuit_line[(index + 1) % 120] - p).normalized()
		for side in [-1.0, 1.0]:
			var candidate: Vector3 = p + Vector3(-forward.z, 0, forward.x) * side * 32.0
			var safe := true
			for step in 24:
				var check := candidate + Vector3(cos(step * TAU / 24) * 13.0, 0, sin(step * TAU / 24) * 13.0)
				if world._nearest(check.x, check.z).x < world.arena.track_width * 0.5 + 4.0 or world.ground_height(check.x, check.z) < -2.0 or preload("res://src/arenas/race_structures.gd").excavation(world.arena, check) > 0.1:
					safe = false
			if safe and (sites.is_empty() or candidate.distance_to(sites[0]) > 40):
				candidate.y = world.ground_height(candidate.x, candidate.z)
				return candidate
	push_error("No safe woodland clearing found")
	return Vector3(180, world.ground_height(180, 0), 0)

func _waterfall(site: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Waterfall%d" % sites.size()
	root.position = site + Vector3(0, 0, -10)
	add_child(root)
	for i in 5:
		var rock := MeshInstance3D.new()
		rock.mesh = world._rock_meshes[i % world._rock_meshes.size()]
		var bounds := rock.mesh.get_aabb()
		rock.scale = Vector3(6, 16, 7) / bounds.size
		rock.position = Vector3((i - 2) * 3.0, -1.0, 0) - bounds.get_center() * rock.scale + Vector3.UP * 8
		root.add_child(rock)
	var material := ShaderMaterial.new()
	material.shader = load("res://src/arenas/forest_waterfall.gdshader")
	water_materials.append(material)
	var water := MeshInstance3D.new()
	water.name = "FallingWater"
	var curtain := PlaneMesh.new()
	curtain.size = Vector2(5.5, 15)
	curtain.subdivide_width = 12
	curtain.subdivide_depth = 16
	water.mesh = curtain
	water.rotation.x = PI * 0.5
	water.position = Vector3(0, 7.3, 4)
	water.material_override = material
	root.add_child(water)
	var pool := MeshInstance3D.new()
	pool.name = "SplashPool"
	var disc := CylinderMesh.new()
	disc.top_radius = 5
	disc.bottom_radius = 5
	disc.height = 0.12
	pool.mesh = disc
	pool.position = Vector3(0, 0.1, 4)
	var pool_material := material.duplicate() as ShaderMaterial
	pool_material.set_shader_parameter("pool", true)
	pool.material_override = pool_material
	water_materials.append(pool_material)
	root.add_child(pool)

func _process(delta: float) -> void:
	if AudioManager.is_suspended():
		return
	advance(delta)

func advance(delta: float) -> void:
	elapsed += delta
	for material in water_materials:
		material.set_shader_parameter("elapsed", elapsed)
	for group_index in groups.size():
		var group: Dictionary = groups[group_index]
		var time := fmod(elapsed + group_index * 9.0, CYCLE)
		var chasing := time >= 6.0 and time < 15.0
		var captured := time >= 15.0 and time < 21.0
		var travel := 0.1 + clampf((time - 6.0) / 9.0, 0.0, 1.0) * 0.55
		if time >= 22.0:
			travel = 0.1
		for i in 4:
			var animal: Node3D = group.animals[i]
			var lag := lerpf(0.2, 0.015, clampf((time - 6) / 9, 0, 1)) if i == 0 else 0.0
			var t := travel - lag + maxf(0, i - 1) * 0.16
			var p := _point(group.path, t)
			animal.position = p
			animal.look_at(_point(group.path, t + 0.015))
			animal.rotate_y(PI)
			animal.animate(time, chasing, captured and i == 1, captured and i == 0)
			animal.visible = time < 21.0 or time >= 23.0
			var fade := clampf(21.0 - time, 0.0, 1.0) if time < 23.0 else time - 23.0
			animal.scale = Vector3.ONE * maxf(0.001, fade)
			if i == 0 and time >= 14 and time < 15:
				animal.position.y += sin((time - 14) * PI) * 0.7

func _point(path: Array, fraction: float) -> Vector3:
	var index := fposmod(fraction, 1.0) * path.size()
	return (path[int(index)] as Vector3).lerp(path[(int(index) + 1) % path.size()], fposmod(index, 1.0))
