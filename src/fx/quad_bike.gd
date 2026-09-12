extends Node3D
## Four-wheel off-road vehicle, with independent wheel pivots and a seated rider.

var _wheels: Array[Node3D] = []
var _steering: Array[Node3D] = []


func build(color: Color, accent: Color) -> Node3D:
	name = "QuadBike"
	rotation.y = PI
	var steel := Color("59616a")
	var black := Color("171b1e")
	for x in [-0.35, 0.35]:
		_bar(Vector3(x, 0.42, -0.9), Vector3(x, 0.42, 0.9), 0.055, steel)
		_bar(Vector3(x, 0.42, -0.75), Vector3(x, 0.85, 0.45), 0.045, steel)
	var motor := MeshFactory.box(Vector3(0.58, 0.5, 0.68), steel)
	_place(motor, Vector3(0, 0.54, 0.1))
	for i in 6:
		_bar(Vector3(-0.32, 0.44 + i * 0.055, -0.24), Vector3(0.32, 0.44 + i * 0.055, -0.24), 0.018, black)
	for front in [true, false]:
		var z := -0.77 if front else 0.77
		for side in [-1, 1]:
			_wheel(side, z, front, steel)
			_bar(Vector3(side * 0.25, 0.57, z), Vector3(side * 0.87, 0.44, z), 0.035, steel)
			_bar(Vector3(side * 0.4, 0.87, z), Vector3(side * 0.75, 0.45, z), 0.04, accent)
			var fender := MeshFactory.capsule(0.24, 1.0, color)
			fender.rotation.x = PI / 2
			fender.scale = Vector3(1, 1, 0.35)
			_place(fender, Vector3(side * 0.65, 0.92, z))
	var fairing := MeshFactory.sphere(0.65, color)
	fairing.scale = Vector3(0.9, 0.28, 0.85)
	_place(fairing, Vector3(0, 0.94, -0.66))
	var seat := MeshFactory.capsule(0.24, 1.15, black)
	seat.rotation.x = PI / 2
	seat.scale = Vector3(1, 1, 0.4)
	seat.material_override = MeshFactory.rubber(black)
	_place(seat, Vector3(0, 0.98, 0.24))
	_bar(Vector3(0, 0.87, -0.53), Vector3(0, 1.3, -0.38), 0.04, steel)
	_bar(Vector3(-0.47, 1.32, -0.3), Vector3(0.47, 1.32, -0.3), 0.035, steel)
	for side in [-1, 1]:
		_bar(Vector3(side * 0.33, 1.32, -0.3), Vector3(side * 0.5, 1.32, -0.3), 0.055, black)
		_bar(Vector3(side * 0.4, 0.37, -0.1), Vector3(side * 0.65, 0.37, 0.38), 0.055, steel)
		var light := MeshFactory.sphere(0.13, Color("fff2cb"), 0.6)
		light.scale = Vector3(1, 0.65, 0.32)
		_place(light, Vector3(side * 0.34, 0.88, -1.08))
		var tail := MeshFactory.sphere(0.09, Color("b51d25"), 0.25)
		tail.scale = Vector3(1, 0.6, 0.35)
		_place(tail, Vector3(side * 0.42, 0.82, 1.02))
	_bar(Vector3(-0.57, 0.65, -1.12), Vector3(0.57, 0.65, -1.12), 0.055, steel)
	_rider(color, accent)
	_batch_body()
	return self


func _wheel(side: int, z: float, front: bool, steel: Color) -> void:
	var pivot := Node3D.new()
	pivot.name = ("Front" if front else "Rear") + ("LeftWheel" if side < 0 else "RightWheel")
	pivot.position = Vector3(side * 0.9, 0.46, z)
	add_child(pivot)
	var wheel := Node3D.new()
	pivot.add_child(wheel)
	_wheels.append(wheel)
	if front:
		_steering.append(pivot)
	var tire := MeshFactory.torus(0.23, 0.46, Color("161918"))
	tire.rotation.z = PI / 2
	tire.scale.y = 1.45
	tire.material_override = MeshFactory.rubber(Color("161918"))
	wheel.add_child(tire)
	var rim := MeshFactory.cylinder(0.235, 0.34, steel, 0, 24)
	rim.rotation.z = PI / 2
	rim.material_override = MeshFactory.satin(steel, 0.27, 0.8)
	wheel.add_child(rim)
	var hub := MeshFactory.cylinder(0.085, 0.39, Color("262a2d"), 0, 12)
	hub.rotation.z = PI / 2
	wheel.add_child(hub)
	var tread := MultiMeshInstance3D.new()
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	var block := BoxMesh.new()
	block.size = Vector3(0.16, 0.065, 0.11)
	block.material = MeshFactory.rubber(Color("202321"))
	batch.mesh = block
	batch.instance_count = 48
	for i in 48:
		var angle := float(i / 2) * TAU / 24 + (i % 2) * 0.09
		var basis := Basis(Vector3.RIGHT, angle) * Basis(Vector3.UP, 0.3 if i % 2 == 0 else -0.3)
		batch.set_instance_transform(i, Transform3D(basis, Vector3(-0.085 if i % 2 == 0 else 0.085, cos(angle) * 0.45, sin(angle) * 0.45)))
	tread.multimesh = batch
	wheel.add_child(tread)


func _rider(color: Color, accent: Color) -> void:
	var suit := color.darkened(0.5)
	var torso := MeshFactory.capsule(0.25, 0.72, suit)
	torso.material_override = MeshFactory.rubber(suit)
	torso.rotation.x = -0.2
	_place(torso, Vector3(0, 1.36, 0.1))
	var helmet := MeshFactory.sphere(0.29, color)
	_place(helmet, Vector3(0, 1.88, -0.04))
	var visor := MeshFactory.sphere(0.26, Color("17242b"))
	visor.scale = Vector3(0.9, 0.46, 0.36)
	visor.material_override = MeshFactory.satin(Color("17242b"), 0.16, 0.35)
	_place(visor, Vector3(0, 1.89, -0.27))
	for side in [-1, 1]:
		_bar(Vector3(side * 0.2, 1.62, 0.03), Vector3(side * 0.4, 1.38, -0.12), 0.1, suit)
		_bar(Vector3(side * 0.4, 1.38, -0.12), Vector3(side * 0.4, 1.32, -0.3), 0.075, accent.darkened(0.35))
		_bar(Vector3(side * 0.2, 1.05, 0.25), Vector3(side * 0.38, 0.81, -0.16), 0.13, suit)
		_bar(Vector3(side * 0.38, 0.81, -0.16), Vector3(side * 0.48, 0.42, 0.05), 0.1, Color("22282d"))
		var boot := MeshFactory.capsule(0.12, 0.38, Color("181d20"))
		boot.rotation.x = PI / 2
		_place(boot, Vector3(side * 0.48, 0.42, -0.05))


func _place(part: Node3D, p: Vector3) -> void:
	part.position = p
	add_child(part)


func _batch_body() -> void:
	# Merge stationary parts by material; wheels retain their animated pivots.
	var groups := {}
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		for surface in child.mesh.get_surface_count():
			var material: Material = child.get_active_material(surface)
			var key := material.get_instance_id()
			if not groups.has(key):
				var builder := SurfaceTool.new()
				builder.begin(Mesh.PRIMITIVE_TRIANGLES)
				groups[key] = {"builder": builder, "material": material}
			groups[key].builder.append_from(child.mesh, surface, child.transform)
		child.free()
	for group in groups.values():
		var part := MeshInstance3D.new()
		part.mesh = group.builder.commit()
		part.material_override = group.material
		add_child(part)


func _bar(from: Vector3, to: Vector3, radius: float, color: Color) -> void:
	var part := MeshFactory.cylinder(radius, from.distance_to(to), color, 0, 12)
	part.quaternion = Quaternion(Vector3.UP, (to - from).normalized())
	_place(part, (from + to) * 0.5)


func animate(delta: float, speed: float, steering: float) -> void:
	for wheel in _wheels:
		wheel.rotation.x = fposmod(wheel.rotation.x - speed * delta / 0.46, TAU)
	for pivot in _steering:
		pivot.rotation.y = lerp_angle(pivot.rotation.y, -steering * 0.4, minf(delta * 10, 1))
