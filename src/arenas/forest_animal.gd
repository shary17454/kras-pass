extends Node3D
## Lightweight articulated scenery, independent of race physics and randomness.
var legs: Array[Node3D] = []
var body: Node3D
var head: Node3D
var tail: Node3D
var predator := false

func build(is_predator: bool) -> void:
	predator = is_predator
	name = "Tiger" if predator else "Deer"
	body = Node3D.new()
	add_child(body)
	var fur := ShaderMaterial.new()
	fur.shader = load("res://src/arenas/forest_fur.gdshader")
	fur.set_shader_parameter("tiger", predator)
	_part(body, Vector3(0, 1.05, 0), Vector3(0.47, 0.52, 0.95) if predator else Vector3(0.31, 0.43, 0.72), fur)
	_part(body, Vector3(0, 0.9, 0.1), Vector3(0.34, 0.3, 0.7), MeshFactory.satin(Color("e6dcc0"), 0.95))
	head = Node3D.new()
	head.position = Vector3(0, 1.25 if predator else 1.55, 0.72)
	body.add_child(head)
	_part(head, Vector3(0, 0.13, 0), Vector3(0.34, 0.35, 0.36) if predator else Vector3(0.17, 0.31, 0.22), fur)
	_part(head, Vector3(0, -0.02, 0.3), Vector3(0.25, 0.18, 0.22) if predator else Vector3(0.13, 0.15, 0.26), fur)
	_part(head, Vector3(0, 0, 0.48), Vector3(0.10, 0.07, 0.04), MeshFactory.satin(Color("29231d"), 0.8))
	for side in [-1.0, 1.0]:
		_part(head, Vector3(side * (0.27 if predator else 0.19), 0.4, -0.04), Vector3(0.11, 0.14 if predator else 0.25, 0.09), fur)
		_part(head, Vector3(side * (0.26 if predator else 0.15), 0.16, 0.23), Vector3(0.035, 0.04, 0.025), MeshFactory.satin(Color("161914"), 0.4))
		if not predator:
			for segment in 3:
				var antler := MeshFactory.sphere(1.0, Color("85715b"))
				antler.scale = Vector3(0.035, 0.2, 0.035)
				antler.position = Vector3(side * (0.12 + segment * 0.075), 0.5 + segment * 0.23, -0.09 - segment * 0.035)
				antler.rotation.z = side * -0.3
				head.add_child(antler)
		for end in [-1.0, 1.0]:
			var leg := Node3D.new()
			leg.position = Vector3(side * (0.31 if predator else 0.22), 0.98, end * 0.52)
			body.add_child(leg)
			legs.append(leg)
			_part(leg, Vector3(0, -0.32, 0), Vector3(0.15 if predator else 0.075, 0.38, 0.11), fur)
			_part(leg, Vector3(0, -0.74, 0.035), Vector3(0.09 if predator else 0.045, 0.26, 0.07), fur)
			_part(leg, Vector3(0, -0.92, 0.12), Vector3(0.15 if predator else 0.065, 0.085, 0.2 if predator else 0.10), MeshFactory.satin(Color("493a2c"), 0.9))
	tail = Node3D.new()
	tail.position = Vector3(0, 1.15, -0.8)
	body.add_child(tail)
	for i in (6 if predator else 2):
		_part(tail, Vector3(0, i * 0.045, -i * 0.15), Vector3(0.06, 0.07, 0.13), fur)

func _part(parent: Node3D, p: Vector3, size: Vector3, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = p
	part.scale = size
	parent.add_child(part)

func animate(time: float, running: bool, caught: bool, feeding: bool) -> void:
	body.rotation.z = PI * 0.48 if caught else 0.0
	body.position.y = 0.45 if caught else (absf(sin(time * 12)) * 0.16 if running else 0.0)
	for i in legs.size():
		legs[i].rotation.x = 0.0 if caught else sin(time * (12.0 if running else 2.0) + float(i % 2) * PI) * (0.65 if running else 0.06)
	head.rotation.x = (0.65 + sin(time * 4) * 0.1) if feeding else (sin(time * 1.2) * 0.12 if not running else -0.1)
	tail.rotation.y = sin(time * 3) * 0.3
