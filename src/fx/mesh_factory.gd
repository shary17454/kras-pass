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
static var _tex_cache := {}


# --- materials -------------------------------------------------------------

static func _noise_texture(seed: int, frequency: float, size := 256) -> NoiseTexture2D:
	var key := "noise%d_%.3f_%d" % [seed, frequency, size]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = frequency
	noise.fractal_octaves = 5
	noise.fractal_lacunarity = 2.15
	noise.fractal_gain = 0.46
	var tex := NoiseTexture2D.new()
	tex.width = size
	tex.height = size
	tex.seamless = true
	tex.noise = noise
	_tex_cache[key] = tex
	return tex

static func toon(color: Color, emission := 0.0, rim := 0.35) -> StandardMaterial3D:
	var key := "t%s_%.2f_%.2f" % [color.to_html(), emission, rim]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = _noise_texture(1207 + int(color.r8) + int(color.g8) * 3 + int(color.b8) * 7, 0.075, 256)
	m.roughness = 0.38
	m.metallic = 0.02
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.rim_enabled = rim > 0.0
	m.rim = rim
	m.rim_tint = 0.32
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission * 0.85
	_mat_cache[key] = m
	return m


static func ice(color: Color, alpha := 0.78) -> StandardMaterial3D:
	var key := "ice%s_%.2f" % [color.to_html(), alpha]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.albedo_texture = _noise_texture(4071, 0.055, 384)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.11
	m.metallic = 0.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.rim_enabled = true
	m.rim = 0.78
	m.rim_tint = 0.82
	_mat_cache[key] = m
	return m


static func satin(color: Color, roughness := 0.34, metallic := 0.0, rim := 0.18) -> StandardMaterial3D:
	var key := "sat%s_%.2f_%.2f_%.2f" % [color.to_html(), roughness, metallic, rim]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.rim_enabled = rim > 0.0
	m.rim = rim
	m.rim_tint = 0.25
	_mat_cache[key] = m
	return m


static func rubber(color: Color) -> StandardMaterial3D:
	var key := "rub%s" % color.to_html()
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.78
	m.metallic = 0.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_mat_cache[key] = m
	return m


static func water(color: Color, alpha := 0.72) -> StandardMaterial3D:
	var key := "water%s_%.2f" % [color.to_html(), alpha]
	if _mat_cache.has(key):
		return _mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.albedo_texture = _noise_texture(9182, 0.026, 512)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08
	m.metallic = 0.0
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.emission_enabled = true
	m.emission = color.darkened(0.08)
	m.emission_energy_multiplier = 0.18
	m.rim_enabled = true
	m.rim = 0.55
	m.rim_tint = 0.62
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
	_tex_cache.clear()


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
	m.radial_segments = 28
	mi.mesh = m
	mi.material_override = toon(color)
	return mi


static func sphere(radius: float, color: Color, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 36
	m.rings = 18
	mi.mesh = m
	mi.material_override = toon(color, emission)
	return mi


static func capsule(radius: float, height: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0 + 0.01)
	m.radial_segments = 32
	m.rings = 14
	mi.mesh = m
	mi.material_override = toon(color)
	return mi


static func torus(inner: float, outer: float, color: Color, emission := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 56
	m.ring_segments = 20
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
	var body := box(Vector3.ONE * size, color)
	body.material_override = satin(color, 0.48, 0.0, 0.08)
	root.add_child(body)
	var bar := size * 0.14
	for axis in [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD]:
		var edge := box(Vector3.ONE * size * 1.02 - axis * (size * 0.98) + axis * bar, accent)
		edge.material_override = satin(accent, 0.32, 0.02, 0.12)
		root.add_child(edge)
	for i in 4:
		var bolt := sphere(size * 0.055, accent.lightened(0.28), 0.05)
		bolt.position = Vector3(
			(-0.34 if i % 2 == 0 else 0.34) * size,
			0.53 * size,
			(-0.34 if i < 2 else 0.34) * size
		)
		bolt.material_override = satin(accent.lightened(0.2), 0.22, 0.12, 0.05)
		root.add_child(bolt)
	return root


## A faceted gem. Cheap stand-in for a cut stone: two cones back to back.
static func gem(size: float, color: Color) -> Node3D:
	var root := Node3D.new()
	var top := cone(size, size * 1.3, color)
	top.material_override = satin(color.lightened(0.05), 0.06, 0.0, 0.42)
	root.add_child(top)
	var bottom := cone(size, size * 0.8, color)
	bottom.material_override = satin(color.darkened(0.16), 0.08, 0.0, 0.38)
	bottom.rotation_degrees = Vector3(180, 0, 0)
	bottom.position = Vector3(0, -size * 1.05, 0)
	root.add_child(bottom)
	for i in 6:
		var facet := box(Vector3(size * 0.08, size * 0.02, size * 0.62), color.lightened(0.45), 0.25)
		facet.position = Vector3(cos(TAU * i / 6.0) * size * 0.42, size * 0.1, sin(TAU * i / 6.0) * size * 0.42)
		facet.rotation.y = TAU * i / 6.0
		facet.material_override = glow(color.lightened(0.35), 0.42)
		root.add_child(facet)
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
	var orbit := torus(radius * 0.58, radius * 0.64, color.lightened(0.18), 0.55)
	orbit.rotation_degrees = Vector3(70, 0, 18)
	root.add_child(orbit)
	return root


static func ice_chunk(size: float, color: Color) -> Node3D:
	var root := Node3D.new()
	var base := box(Vector3(size * 1.58, size * 0.42, size * 0.9), color)
	base.position = Vector3(0, 0.1, 0)
	base.rotation_degrees = Vector3(0, -5, 1.5)
	base.material_override = ice(color, 0.82)
	root.add_child(base)
	var cap := box(Vector3(size * 1.16, size * 0.3, size * 0.62), color.lightened(0.12))
	cap.position = Vector3(-size * 0.08, size * 0.42, 0)
	cap.rotation_degrees = Vector3(0, 12, -7)
	cap.material_override = ice(color.lightened(0.13), 0.9)
	root.add_child(cap)
	for i in 3:
		var shine := box(Vector3(size * (0.42 - i * 0.07), size * 0.035, size * 0.08), Color(0.95, 1.0, 1.0))
		shine.position = Vector3(size * (-0.26 + i * 0.22), size * (0.58 + i * 0.03), size * (-0.22 + i * 0.18))
		shine.rotation_degrees = Vector3(0, -18 + i * 16, 0)
		shine.material_override = glow(Color(0.90, 0.98, 1.0), 0.42)
		root.add_child(shine)
	for sx in [-1.0, 1.0]:
		var shard := cone(size * 0.18, size * 0.48, color.lightened(0.22))
		shard.position = Vector3(size * 0.5 * sx, size * 0.42, size * 0.18)
		shard.rotation_degrees = Vector3(0, 0, 22 * sx)
		shard.material_override = ice(color.lightened(0.2), 0.74)
		root.add_child(shard)
	return root


static func arctic_mount(slot: int, rider_color: Color, accent: Color) -> Node3D:
	if slot % 2 == 0:
		return penguin_mount(rider_color, accent)
	return seal_mount(rider_color, accent)


static func penguin_mount(rider_color: Color, accent: Color) -> Node3D:
	var root := Node3D.new()
	var body := capsule(0.42, 1.02, Color(0.035, 0.055, 0.075))
	body.position = Vector3(0, 0.47, 0)
	body.scale = Vector3(1.05, 0.78, 1.2)
	body.material_override = satin(Color(0.025, 0.038, 0.052), 0.28, 0.0, 0.18)
	root.add_child(body)

	var belly := sphere(0.34, Color(0.94, 0.98, 0.96))
	belly.position = Vector3(0, 0.46, -0.27)
	belly.scale = Vector3(0.72, 0.9, 0.35)
	belly.material_override = satin(Color(0.94, 0.98, 0.96), 0.22, 0.0, 0.1)
	root.add_child(belly)
	var cheek := sphere(0.13, Color(1.0, 0.82, 0.68))
	cheek.position = Vector3(0.0, 0.9, -0.39)
	cheek.scale = Vector3(1.6, 0.45, 0.35)
	root.add_child(cheek)

	var head := sphere(0.34, Color(0.035, 0.055, 0.075))
	head.position = Vector3(0, 0.98, -0.1)
	head.material_override = satin(Color(0.025, 0.038, 0.052), 0.24, 0.0, 0.16)
	root.add_child(head)

	var beak := cone(0.12, 0.28, Color(1.0, 0.64, 0.22))
	beak.rotation_degrees = Vector3(90, 0, 0)
	beak.position = Vector3(0, 0.96, -0.43)
	root.add_child(beak)

	for sx in [-1.0, 1.0]:
		var eye := sphere(0.045, Color(0.02, 0.02, 0.025))
		eye.position = Vector3(0.11 * sx, 1.06, -0.38)
		root.add_child(eye)
		var glint := sphere(0.014, Color.WHITE, 0.1)
		glint.position = Vector3(0.125 * sx, 1.075, -0.414)
		root.add_child(glint)
		var flipper := box(Vector3(0.12, 0.48, 0.18), Color(0.025, 0.04, 0.06))
		flipper.position = Vector3(0.38 * sx, 0.46, -0.03)
		flipper.rotation_degrees = Vector3(0, 0, 24 * sx)
		flipper.material_override = satin(Color(0.018, 0.028, 0.04), 0.42, 0.0, 0.08)
		root.add_child(flipper)
		var foot := box(Vector3(0.28, 0.06, 0.22), Color(1.0, 0.58, 0.18))
		foot.position = Vector3(0.18 * sx, 0.05, -0.28)
		foot.material_override = satin(Color(1.0, 0.58, 0.18), 0.36, 0.0, 0.08)
		root.add_child(foot)

	var saddle := torus(0.28, 0.39, rider_color, 0.25)
	saddle.position = Vector3(0, 0.9, 0.08)
	saddle.rotation_degrees = Vector3(90, 0, 0)
	saddle.material_override = satin(rider_color, 0.22, 0.04, 0.12)
	root.add_child(saddle)
	var reins := box(Vector3(0.06, 0.04, 0.62), accent)
	reins.position = Vector3(0, 1.03, -0.08)
	reins.material_override = satin(accent, 0.24, 0.05, 0.1)
	root.add_child(reins)
	var shadow := sphere(0.36, Color(0.0, 0.0, 0.0))
	shadow.position = Vector3(0, 0.015, 0.1)
	shadow.scale = Vector3(1.5, 0.035, 1.05)
	shadow.material_override = transparent(Color(0, 0, 0), 0.24)
	root.add_child(shadow)
	return root


static func seal_mount(rider_color: Color, accent: Color) -> Node3D:
	var root := Node3D.new()
	var body := capsule(0.42, 1.15, Color(0.56, 0.68, 0.72))
	body.position = Vector3(0, 0.4, 0)
	body.rotation_degrees = Vector3(90, 0, 0)
	body.scale = Vector3(1.0, 0.85, 1.22)
	body.material_override = satin(Color(0.50, 0.62, 0.68), 0.36, 0.0, 0.12)
	root.add_child(body)

	var chest := sphere(0.34, Color(0.82, 0.91, 0.92))
	chest.position = Vector3(0, 0.4, -0.33)
	chest.scale = Vector3(0.78, 0.55, 0.32)
	root.add_child(chest)

	var head := sphere(0.32, Color(0.60, 0.72, 0.76))
	head.position = Vector3(0, 0.56, -0.7)
	head.material_override = satin(Color(0.56, 0.68, 0.73), 0.32, 0.0, 0.12)
	root.add_child(head)

	var muzzle := sphere(0.14, Color(0.90, 0.94, 0.92))
	muzzle.position = Vector3(0, 0.53, -0.97)
	muzzle.scale = Vector3(1.35, 0.78, 0.72)
	root.add_child(muzzle)
	var nose := sphere(0.055, Color(0.06, 0.07, 0.08))
	nose.position = Vector3(0, 0.57, -1.09)
	nose.scale = Vector3(1.25, 0.7, 0.85)
	root.add_child(nose)

	for sx in [-1.0, 1.0]:
		var eye := sphere(0.045, Color(0.02, 0.025, 0.03))
		eye.position = Vector3(0.11 * sx, 0.66, -0.94)
		root.add_child(eye)
		var glint := sphere(0.014, Color.WHITE, 0.1)
		glint.position = Vector3(0.125 * sx, 0.675, -0.975)
		root.add_child(glint)
		var whisker := box(Vector3(0.34, 0.018, 0.018), Color(0.95, 0.98, 0.96))
		whisker.position = Vector3(0.2 * sx, 0.53, -1.04)
		whisker.rotation_degrees = Vector3(0, 18 * sx, 0)
		whisker.material_override = satin(Color(0.95, 0.98, 0.96), 0.18, 0.0, 0.0)
		root.add_child(whisker)
		var flipper := box(Vector3(0.15, 0.08, 0.55), Color(0.46, 0.58, 0.64))
		flipper.position = Vector3(0.42 * sx, 0.18, -0.1)
		flipper.rotation_degrees = Vector3(0, 18 * sx, 0)
		flipper.material_override = satin(Color(0.43, 0.55, 0.61), 0.42, 0.0, 0.06)
		root.add_child(flipper)
		for j in 3:
			var spot := sphere(0.028, Color(0.36, 0.47, 0.52))
			spot.position = Vector3((0.16 + 0.08 * j) * sx, 0.74 - 0.035 * j, -0.78 - 0.03 * j)
			spot.scale = Vector3(1.25, 0.5, 1.0)
			spot.material_override = satin(Color(0.36, 0.47, 0.52), 0.5, 0.0, 0.02)
			root.add_child(spot)

	var saddle := torus(0.3, 0.42, rider_color, 0.22)
	saddle.position = Vector3(0, 0.84, -0.05)
	saddle.rotation_degrees = Vector3(90, 0, 0)
	saddle.material_override = satin(rider_color, 0.24, 0.04, 0.12)
	root.add_child(saddle)
	var strap := box(Vector3(0.7, 0.05, 0.08), accent)
	strap.position = Vector3(0, 0.72, -0.05)
	strap.material_override = satin(accent, 0.25, 0.05, 0.1)
	root.add_child(strap)
	var shadow := sphere(0.42, Color(0.0, 0.0, 0.0))
	shadow.position = Vector3(0, 0.015, 0.02)
	shadow.scale = Vector3(1.65, 0.035, 1.1)
	shadow.material_override = transparent(Color(0, 0, 0), 0.24)
	root.add_child(shadow)
	return root


## A small kart: body, cabin, four wheels. Used by the vehicle games.
static func kart(color: Color, accent: Color) -> Node3D:
	var root := Node3D.new()
	var body := box(Vector3(1.5, 0.45, 2.1), color)
	body.position = Vector3(0, 0.42, 0)
	body.material_override = satin(color, 0.2, 0.08, 0.14)
	root.add_child(body)
	var cabin := box(Vector3(0.95, 0.5, 0.9), accent)
	cabin.position = Vector3(0, 0.85, -0.15)
	cabin.material_override = satin(accent, 0.16, 0.05, 0.14)
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
			w.material_override = rubber(Color(0.04, 0.04, 0.052))
			root.add_child(w)
			var rim := cylinder(0.18, 0.255, accent.lightened(0.1), 0.1, 18)
			rim.rotation_degrees = Vector3(0, 0, 90)
			rim.position = w.position
			rim.material_override = satin(accent.lightened(0.1), 0.16, 0.25, 0.06)
			root.add_child(rim)
	for sx in [-1.0, 1.0]:
		var headlight := sphere(0.11, Color(1.0, 0.9, 0.62), 0.8)
		headlight.position = Vector3(0.32 * sx, 0.5, -1.18)
		root.add_child(headlight)
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
			b.material_override = satin(c, 0.32, 0.0, 0.12)
			root.add_child(b)
		"orb":
			var b := sphere(0.55 * g, c)
			b.position = Vector3(0, 0.66 * h, 0)
			b.material_override = satin(c, 0.26, 0.0, 0.14)
			root.add_child(b)
		"shard":
			var b := cone(0.55 * g, 1.35 * h, c)
			b.position = Vector3(0, 0.68 * h, 0)
			b.material_override = satin(c, 0.18, 0.0, 0.22)
			root.add_child(b)
		"drum":
			var b := cylinder(0.5 * g, 1.05 * h, c)
			b.position = Vector3(0, 0.55 * h, 0)
			b.material_override = satin(c, 0.30, 0.0, 0.12)
			root.add_child(b)
		_:
			var b := capsule(0.42 * g, 1.25 * h, c)
			b.position = Vector3(0, 0.66 * h, 0)
			b.material_override = satin(c, 0.30, 0.0, 0.12)
			root.add_child(b)

	var head_y := 1.28 * h
	match data.head_shape:
		"cube":
			var hd := box(Vector3.ONE * 0.62, c.lightened(0.12))
			hd.position = Vector3(0, head_y, 0)
			hd.material_override = satin(c.lightened(0.12), 0.28, 0.0, 0.1)
			root.add_child(hd)
		"cone":
			var hd := cone(0.36, 0.62, c.lightened(0.12))
			hd.position = Vector3(0, head_y, 0)
			hd.material_override = satin(c.lightened(0.12), 0.20, 0.0, 0.18)
			root.add_child(hd)
		_:
			var hd := sphere(0.36, c.lightened(0.12))
			hd.position = Vector3(0, head_y, 0)
			hd.material_override = satin(c.lightened(0.12), 0.24, 0.0, 0.12)
			root.add_child(hd)

	# Eyes give the body an unambiguous facing direction, which matters in
	# every push-out game where players read each other's aim.
	for sx in [-1.0, 1.0]:
		var eye := sphere(0.1, Color(0.06, 0.06, 0.09))
		eye.position = Vector3(0.15 * sx, head_y + 0.05, -0.3)
		eye.material_override = satin(Color(0.015, 0.015, 0.02), 0.08, 0.0, 0.0)
		root.add_child(eye)
		var glint := sphere(0.026, Color.WHITE, 0.25)
		glint.position = Vector3(0.18 * sx, head_y + 0.085, -0.37)
		root.add_child(glint)

	var acc := _accessory(data.accessory, a)
	if acc != null:
		acc.position = Vector3(0, head_y + 0.34, 0)
		root.add_child(acc)

	var band := torus(0.4 * g, 0.5 * g, a, 0.25)
	band.position = Vector3(0, 0.3 * h, 0)
	band.material_override = satin(a, 0.22, 0.05, 0.12)
	root.add_child(band)
	var shadow := sphere(0.45 * g, Color(0.0, 0.0, 0.0))
	shadow.position = Vector3(0, 0.015, 0.0)
	shadow.scale = Vector3(1.35, 0.035, 1.05)
	shadow.material_override = transparent(Color(0, 0, 0), 0.18)
	root.add_child(shadow)
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
