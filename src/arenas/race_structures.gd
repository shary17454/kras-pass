extends Node3D
## Road stays the authoritative collision ribbon; earth is cut beneath its bridge.
const BRIDGE := 26
const TUNNEL_START := 66
const TUNNEL_END := 76
var arena: Arena


static func bridge_coordinates(a: Arena, p: Vector3) -> Vector2:
	var origin := a.circuit_line[BRIDGE]
	var forward := (a.circuit_line[BRIDGE + 4] - a.circuit_line[BRIDGE - 4]).normalized()
	forward.y = 0.0
	forward = forward.normalized()
	var across := Vector3(-forward.z, 0, forward.x)
	var delta := p - origin
	return Vector2(delta.dot(forward), delta.dot(across))


static func excavation(a: Arena, p: Vector3) -> float:
	if a.circuit_line.size() < 80:
		return 0.0
	var local := bridge_coordinates(a, p)
	return 12.0 * (1.0 - smoothstep(8.0, 23.0, absf(local.x))) * (1.0 - smoothstep(25.0, 45.0, absf(local.y)))


func build(a: Arena) -> void:
	name = "RaceStructures"
	arena = a
	_bridge()
	_tunnel()
	if a.def.id == "magma_ring":
		var lava := MeshInstance3D.new()
		lava.name = "LavaUnderBridge"
		var plane := PlaneMesh.new()
		plane.size = Vector2(150, 38)
		lava.mesh = plane
		lava.position = a.circuit_line[BRIDGE] + Vector3.DOWN * 5.5
		var forward := a.circuit_line[BRIDGE + 4] - a.circuit_line[BRIDGE - 4]
		forward.y = 0
		lava.basis = Basis.looking_at(forward.normalized(), Vector3.UP)
		var material := ShaderMaterial.new()
		material.shader = load("res://src/arenas/racing_lava.gdshader")
		lava.material_override = material
		add_child(lava)


func is_below_bridge(p: Vector3) -> bool:
	if excavation(arena, p) < 0.5:
		return false
	var world := arena.get_node_or_null("FantasyWorld")
	if world == null:
		return false
	var nearest: Vector3 = world._nearest(p.x, p.z)
	# Catch shallow bank ledges too; otherwise a racer can stay trapped there.
	return p.y < nearest.y - 0.5


func _beam(a: Vector3, b: Vector3, width: float, height: float, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, height, a.distance_to(b))
	var beam := MeshInstance3D.new()
	beam.mesh = mesh
	beam.material_override = MeshFactory.satin(color, 0.8)
	beam.position = (a + b) * 0.5
	beam.basis = Basis.looking_at((b - a).normalized(), Vector3.UP)
	add_child(beam)


func _bridge() -> void:
	var color := Color("66584a") if arena.def.id in ["sinbad_coast", "pharaoh_valley"] else Color("72797c")
	for i in range(BRIDGE - 6, BRIDGE + 6):
		var a := arena.circuit_line[i]
		var b := arena.circuit_line[i + 1]
		var forward := (b - a).normalized()
		var across := Vector3(-forward.z, 0, forward.x).normalized()
		_beam(a + Vector3.DOWN * 0.4, b + Vector3.DOWN * 0.4, arena.track_width, 0.7, color)
		for side in [-1.0, 1.0]:
			var offset: Vector3 = across * side * (arena.track_width * 0.5 - 0.5)
			_beam(a + offset + Vector3.DOWN * 0.9, b + offset + Vector3.DOWN * 2.2, 0.3, 0.3, color.darkened(0.2))
		if i % 3 == 0:
			var cross := a + Vector3.DOWN * 0.9
			_beam(cross - across * arena.track_width * 0.5, cross + across * arena.track_width * 0.5, 0.3, 0.4, color)
	# Piers sit below the bridge rather than forming invisible roadside walls.
	for i in [BRIDGE - 3, BRIDGE + 3]:
		var p := arena.circuit_line[i]
		for side in [-1.0, 1.0]:
			var forward := (arena.circuit_line[i + 1] - p).normalized()
			var across := Vector3(-forward.z, 0, forward.x).normalized()
			var column := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.65
			mesh.bottom_radius = 1.0
			mesh.height = 12
			column.mesh = mesh
			column.material_override = MeshFactory.satin(color, 0.85)
			column.position = p + across * side * (arena.track_width * 0.5 - 1.2) + Vector3.DOWN * 6.3
			add_child(column)


func _tunnel() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(TUNNEL_START, TUNNEL_END):
		for arc in 20:
			for pair in [Vector2i(index, arc), Vector2i(index + 1, arc), Vector2i(index, arc + 1), Vector2i(index, arc + 1), Vector2i(index + 1, arc), Vector2i(index + 1, arc + 1)]:
				var center := arena.circuit_line[pair.x]
				var forward := (arena.circuit_line[pair.x + 1] - arena.circuit_line[pair.x - 1]).normalized()
				var across := Vector3(-forward.z, 0, forward.x).normalized()
				var angle := float(pair.y) * PI / 20.0
				surface.set_uv(Vector2(pair.x * 0.6, pair.y * 0.35))
				surface.add_vertex(center + across * cos(angle) * (arena.track_width * 0.5 + 3.0) + Vector3.UP * (sin(angle) * 8.0 - 0.3))
	surface.generate_normals()
	var shell := MeshInstance3D.new()
	shell.name = "TunnelShell"
	shell.mesh = surface.commit()
	var material := MeshFactory.satin(Color("77746a"), 0.85).duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell.material_override = material
	add_child(shell)
	var body := StaticBody3D.new()
	body.name = "TunnelCollision"
	var collision := CollisionShape3D.new()
	collision.shape = shell.mesh.create_trimesh_shape()
	collision.shape.backface_collision = true
	body.add_child(collision)
	add_child(body)
	for index in range(TUNNEL_START, TUNNEL_END + 1, 2):
		var lamp := MeshFactory.sphere(0.18, Color("ffe5a8"), 1.2)
		lamp.position = arena.circuit_line[index] + Vector3.UP * 7.1
		add_child(lamp)
		if index % 4 == 2:
			var light := OmniLight3D.new()
			light.position = arena.circuit_line[index] + Vector3.UP * 5.0
			light.light_color = Color("ffe5bf")
			light.light_energy = 1.8
			light.omni_range = 13.0
			light.shadow_enabled = false
			add_child(light)
