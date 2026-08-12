class_name MeshFactory
extends RefCounted
## Procedural art. Every visible object in the game is generated here.
##
## The project ships with no imported models, textures or audio files: nothing
## is borrowed from anything, and the whole look is defined by numbers a person
## can edit. When authored assets arrive, each `make_*` becomes a two-line
## loader and the rest of the game is untouched.
##
## Materials are cached by colour+style because a 4-player match with pickups
## can otherwise allocate hundreds of identical StandardMaterial3D instances.

static var _mat_cache := {}


# --- materials -------------------------------------------------------------

static func toon(color: Color, emission := 0.0, rim := 0.35) -> StandardMaterial3D:
	var key := "t%s_%.2f_%.2f" % [color.to_html(), emission, rim]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.62
	m.metallic = 0.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.rim_enabled = rim > 0.0
	m.rim = rim
	m.rim_tint = 0.4
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	_mat_cache[key] = m
	return m


static func glow(color: Color, energy := 1.6) -> StandardMaterial3D:
	var key := "g%s_%.2f" % [color.to_html(), energy]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_mat_cache[key] = m
	return m


static func transparent(color: Color, alpha := 0.4) -> StandardMaterial3D:
	var key := "x%s_%.2f" % [color.to_html(), alpha]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_cache[key] = m
	return m


static func clear_cache() -> void:
	_mat_cache.clear()


# --- primitives ------------------------------------------------------------

static func box(size: Vector3, color: Color, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = toon(color, emission)
	return mi


static func cylinder(radius: float, height: float, color: Color, emission := 0.0, sides := 24) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	mi.mesh = m
	mi.material_override = toon(color, emission)
	return mi


static func cone(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 16
	mi.mesh = m
	mi.material_override = toon(color)
	return mi


static func sphere(radius: float, color: Color, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 20
	m.rings = 10
	mi.mesh = m
	mi.material_override = toon(color, emission)
	return mi


static func capsule(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0 + 0.01)
	m.radial_segments = 18
	m.rings = 8
	mi.mesh = m
	mi.material_override = toon(color)
	return mi


static func torus(inner: float, outer: float, color: Color, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 24
	m.ring_segments = 10
	mi.mesh = m
	mi.material_override = toon(color, emission)
	return mi


static func plane(size: Vector2, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := PlaneMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = toon(color)
	return mi


# --- composite pieces ------------------------------------------------------

## A crate: chunky box with contrasting edge bars, readable at arena distance.
static func crate(size: float, color: Color, accent: Color) -> Node3D:
	var root := Node3D.new()
	root.add_child(box(Vector3.ONE * size, color))
	var bar := size * 0.14
	for axis in [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD]:
		var edge := box(Vector3.ONE * size * 1.02 - axis * (size * 0.98) + axis * bar, accent)
		root.add_child(edge)
	return root


## A faceted gem. Cheap stand-in for a cut stone: two cones back to back.
static func gem(size: float, color: Color) -> Node3D:
	var root := Node3D.new()
	var top := cone(size, size * 1.3, color)
	top.material_override = glow(color, 1.1)
	root.add_child(top)
	var bottom := cone(size, size * 0.8, color)
	bottom.material_override = glow(color.darkened(0.2), 0.9)
	bottom.rotation_degrees = Vector3(180, 0, 0)
	bottom.position = Vector3(0, -size * 1.05, 0)
	root.add_child(bottom)
	return root


## Pickup bubble used by every power-up: a translucent shell with a core.
static func pickup_shell(color: Color, radius := 0.55) -> Node3D:
	var root := Node3D.new()
	var shell := sphere(radius, color)
	shell.material_override = transparent(color, 0.32)
	root.add_child(shell)
	var core := sphere(radius * 0.5, color)
	core.material_override = glow(color, 2.0)
	root.add_child(core)
	return root


## A small kart: body, cabin, four wheels. Used by the vehicle games.
static func kart(color: Color, accent: Color) -> Node3D:
	var root := Node3D.new()
	var body := box(Vector3(1.5, 0.45, 2.1), color)
	body.position = Vector3(0, 0.42, 0)
	root.add_child(body)
	var cabin := box(Vector3(0.95, 0.5, 0.9), accent)
	cabin.position = Vector3(0, 0.85, -0.15)
	root.add_child(cabin)
	var nose := cone(0.42, 0.7, accent)
	nose.rotation_degrees = Vector3(-90, 0, 0)
	nose.position = Vector3(0, 0.45, -1.15)
	root.add_child(nose)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var w := cylinder(0.33, 0.24, Color(0.12, 0.12, 0.16), 0.0, 14)
			w.rotation_degrees = Vector3(0, 0, 90)
			w.position = Vector3(0.78 * sx, 0.33, 0.72 * sz)
			root.add_child(w)
	return root


## Character body assembled from the recipe in CharacterData. Distinct
## silhouettes matter more than detail: players must tell four bodies apart
## while all four are moving and half-hidden behind effects.
static func character_body(data: CharacterData) -> Node3D:
	var root := Node3D.new()
	var c := data.color
	var a := data.accent
	var h := data.height_scale
	var g := data.girth_scale

	match data.body_shape:
		"boulder":
			var b := sphere(0.62 * g, c)
			b.scale = Vector3(1.0, 0.85 * h, 1.0)
			b.position = Vector3(0, 0.62 * h, 0)
			root.add_child(b)
		"orb":
			var b := sphere(0.55 * g, c)
			b.position = Vector3(0, 0.66 * h, 0)
			root.add_child(b)
		"shard":
			var b := cone(0.55 * g, 1.35 * h, c)
			b.position = Vector3(0, 0.68 * h, 0)
			root.add_child(b)
		"drum":
			var b := cylinder(0.5 * g, 1.05 * h, c)
			b.position = Vector3(0, 0.55 * h, 0)
			root.add_child(b)
		_:
			var b := capsule(0.42 * g, 1.25 * h, c)
			b.position = Vector3(0, 0.66 * h, 0)
			root.add_child(b)

	var head_y := 1.28 * h
	match data.head_shape:
		"cube":
			var hd := box(Vector3.ONE * 0.62, c.lightened(0.12))
			hd.position = Vector3(0, head_y, 0)
			root.add_child(hd)
		"cone":
			var hd := cone(0.36, 0.62, c.lightened(0.12))
			hd.position = Vector3(0, head_y, 0)
			root.add_child(hd)
		_:
			var hd := sphere(0.36, c.lightened(0.12))
			hd.position = Vector3(0, head_y, 0)
			root.add_child(hd)

	# Eyes give the body an unambiguous facing direction, which matters in
	# every push-out game where players read each other's aim.
	for sx in [-1.0, 1.0]:
		var eye := sphere(0.1, Color(0.06, 0.06, 0.09))
		eye.position = Vector3(0.15 * sx, head_y + 0.05, -0.3)
		root.add_child(eye)

	var acc := _accessory(data.accessory, a)
	if acc != null:
		acc.position = Vector3(0, head_y + 0.34, 0)
		root.add_child(acc)

	var band := torus(0.4 * g, 0.5 * g, a, 0.25)
	band.position = Vector3(0, 0.3 * h, 0)
	root.add_child(band)
	return root


static func _accessory(kind: String, color: Color) -> Node3D:
	match kind:
		"leaf":
			var n := Node3D.new()
			for i in 3:
				var l := box(Vector3(0.09, 0.36, 0.22), color)
				l.rotation_degrees = Vector3(-22, 120.0 * i, 0)
				l.position = Vector3(sin(TAU * i / 3.0) * 0.1, 0.14, cos(TAU * i / 3.0) * 0.1)
				n.add_child(l)
			return n
		"crack":
			var n := Node3D.new()
			var s := box(Vector3(0.5, 0.14, 0.5), color)
			n.add_child(s)
			return n
		"spark":
			var n := Node3D.new()
			for i in 4:
				var s := box(Vector3(0.06, 0.34, 0.06), color)
				s.material_override = glow(color, 2.2)
				s.rotation_degrees = Vector3(28, 90.0 * i, 18)
				n.add_child(s)
			return n
		"flame":
			var f := cone(0.2, 0.5, color)
			f.material_override = glow(color, 2.0)
			return f
		"wave":
			var n := Node3D.new()
			var t := torus(0.16, 0.3, color, 0.6)
			t.rotation_degrees = Vector3(74, 0, 0)
			n.add_child(t)
			return n
		"puff":
			var n := Node3D.new()
			for i in 3:
				var s := sphere(0.19, color)
				s.position = Vector3(cos(TAU * i / 3.0) * 0.18, 0.02 * i, sin(TAU * i / 3.0) * 0.18)
				n.add_child(s)
			return n
		"grain":
			var n := Node3D.new()
			for i in 5:
				var s := box(Vector3.ONE * 0.11, color)
				s.position = Vector3(cos(TAU * i / 5.0) * 0.22, 0.05, sin(TAU * i / 5.0) * 0.22)
				n.add_child(s)
			return n
		"cog":
			var n := Node3D.new()
			var hub := cylinder(0.2, 0.1, color, 0.2, 10)
			hub.rotation_degrees = Vector3(90, 0, 0)
			n.add_child(hub)
			for i in 8:
				var tooth := box(Vector3(0.08, 0.08, 0.12), color)
				tooth.position = Vector3(cos(TAU * i / 8.0) * 0.26, 0, sin(TAU * i / 8.0) * 0.26)
				n.add_child(tooth)
			return n
	return null


## Simple burst of shards, used for hits, breaks and eliminations. Returns a
## node that removes itself; the caller does not need to track it.
static func burst(color: Color, count := 10, spread := 2.4, life := 0.55) -> Node3D:
	var root := Node3D.new()
	var script := load("res://src/fx/burst.gd")
	root.set_script(script)
	root.configure(color, count, spread, life)
	return root
