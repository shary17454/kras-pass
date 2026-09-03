class_name Arena
extends Node3D
## A generated venue.
##
## `build(def)` turns an `ArenaDef` into geometry, collision, lighting, sky and
## live hazards. Ten shape families cover all 23 venues in the game; a new venue
## is a JSON entry, and a genuinely new *kind* of venue is one `_build_*` here.
##
## Gameplay never reaches into the geometry: it asks `is_inside()`,
## `edge_distance()`, `spawn_points`, `tiles` and `fall_y`.

signal tile_collapsed(tile: ArenaTile)
signal radius_changed(r: float)
signal fighter_submerged(fighter)

const TILE_SIZE := 2.0

var def: ArenaDef
var tiles: Array[ArenaTile] = []
var spawn_points: Array[Vector3] = []
var fall_y := -14.0
var current_radius := 12.0

# Track/oval extras, read by the racing games.
var track_length := 0.0
var lane_count := 4
var checkpoints: Array[Vector3] = []
## Racing line of a `circuit`, sampled once at build time. Every "am I on the
## track?" query walks this instead of solving the curve, because the curve is
## only defined implicitly and the AI asks several times per frame.
var circuit_line: PackedVector3Array = []
var track_width := 8.0
var finish_z := 0.0
var start_z := 0.0

var _hazards: Array = []
var _shrink: ArenaHazards.ShrinkRing
## Original speeds, so a hazard multiplier is idempotent rather than cumulative.
var _base_hazard_speed := {}
var _water: ArenaHazards.RisingWater
var _static_root: Node3D
var _light: DirectionalLight3D
var _env: WorldEnvironment
## Disc floor pieces, kept so a shrinking arena can move its real collision
## edge rather than only its painted one.
var _floor_mesh: MeshInstance3D
var _floor_shape: CylinderShape3D
var _arctic_water_layers: Array = []
var _arctic_waves: Array = []
var _arctic_floes: Array = []
var _arctic_shrink_followers: Array[Node3D] = []
var _arctic_time := 0.0


func build(arena_def: ArenaDef) -> void:
	def = arena_def
	fall_y = def.fall_y
	current_radius = def.radius
	_static_root = Node3D.new()
	_static_root.name = "Static"
	add_child(_static_root)
	_build_environment()
	match def.shape:
		"square": _build_square()
		"ring": _build_ring()
		"cross": _build_cross()
		"tiles": _build_tiles(true)
		"grid": _build_tiles(false)
		"track": _build_track()
		"oval": _build_oval()
		"circuit": _build_circuit()
		"pit": _build_pit()
		"islands": _build_islands()
		_: _build_disc()
	if _is_arctic():
		_add_arctic_set_dressing()
	if def.wall_height > 0.0:
		_build_walls()
	_build_hazards()
	if spawn_points.is_empty():
		spawn_points = def.spawns_for(4)


# --- queries used by gameplay and AI ---------------------------------------

func is_inside(pos: Vector3, margin: float = 0.0) -> bool:
	var p := Vector2(pos.x - global_position.x, pos.z - global_position.z)
	match def.shape:
		"square", "grid", "tiles":
			var r := current_radius - margin
			return absf(p.x) <= r and absf(p.y) <= r
		"ring":
			var d := p.length()
			return d <= current_radius - margin and d >= current_radius * 0.42 + margin
		"track":
			return absf(p.x) <= current_radius * 0.7 - margin and absf(p.y) <= track_length * 0.5
		"oval":
			var d := p.length()
			return d <= current_radius - margin and d >= current_radius * 0.5 + margin
		"circuit":
			return _circuit_offset(pos) <= track_width * 0.5 - margin
		_:
			return p.length() <= current_radius - margin


## Distance to the nearest lethal edge. Negative when already outside. The AI's
## edge-awareness and every "shove them off" heuristic read this.
func edge_distance(pos: Vector3) -> float:
	var p := Vector2(pos.x - global_position.x, pos.z - global_position.z)
	match def.shape:
		"square", "grid", "tiles":
			return current_radius - maxf(absf(p.x), absf(p.y))
		"ring", "oval":
			var d := p.length()
			return minf(current_radius - d, d - current_radius * 0.45)
		"track":
			return current_radius * 0.7 - absf(p.x)
		"circuit":
			return track_width * 0.5 - _circuit_offset(pos)
		_:
			return current_radius - p.length()


func center() -> Vector3:
	return global_position


## Safe point to steer toward when a fighter is near an edge.
func retreat_point(pos: Vector3) -> Vector3:
	if def.shape == "ring" or def.shape == "oval":
		var dir := Vector3(pos.x, 0, pos.z).normalized()
		return global_position + dir * current_radius * 0.72
	if def.shape == "circuit":
		# Back onto the racing line, not toward the middle: the middle of a
		# circuit is off the track entirely.
		return _circuit_nearest(pos)
	return global_position + Vector3(0, pos.y, 0)


func tile_at(pos: Vector3) -> ArenaTile:
	var best: ArenaTile = null
	var best_d := TILE_SIZE * 0.75
	for t in tiles:
		if t == null or not is_instance_valid(t):
			continue
		var d := Vector2(t.global_position.x - pos.x, t.global_position.z - pos.z).length()
		if d < best_d:
			best_d = d
			best = t
	return best


func tick(delta: float) -> void:
	_tick_arctic_water(delta)
	for h in _hazards:
		if is_instance_valid(h):
			h.tick(delta)
	for t in tiles:
		if is_instance_valid(t):
			t.tick(delta)


func check_water(fighters: Array) -> void:
	if _water != null and is_instance_valid(_water):
		_water.check(fighters)


func water_level() -> float:
	return _water.level if _water != null and is_instance_valid(_water) else -INF


## Multiplies every moving hazard's speed. Used by the double_hazards mutator;
## arenas without moving parts simply ignore it.
func set_hazard_speed(scale: float) -> void:
	for h in _hazards:
		if not is_instance_valid(h):
			continue
		if h is ArenaHazards.Sweeper:
			h.speed = _base_hazard_speed.get(h.get_instance_id(), h.speed) * scale
		elif h is ArenaHazards.RisingWater:
			h.speed = _base_hazard_speed.get(h.get_instance_id(), h.speed) * scale


func reset_hazards() -> void:
	if _shrink != null and is_instance_valid(_shrink):
		_shrink.reset()
		current_radius = def.radius
		_on_radius_changed(current_radius)
	if _water != null and is_instance_valid(_water):
		var start := -6.0
		for h in def.hazards:
			if String(h.get("type", "")) == "rising":
				start = float(h.get("start_y", -6.0))
		_water.reset(start)
	for h in _hazards:
		if h is ArenaHazards.BreakableIceBarrier and is_instance_valid(h):
			h.reset()
	for t in tiles:
		if is_instance_valid(t):
			t.restore()
			t.owner_slot = -1
			t.set_color(t.base_color)


# --- environment -----------------------------------------------------------

func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	if _is_arctic():
		mat.sky_top_color = Color(0.015, 0.055, 0.105)
		mat.sky_horizon_color = Color(0.16, 0.42, 0.56)
		mat.ground_bottom_color = Color(0.01, 0.04, 0.07)
		mat.ground_horizon_color = Color(0.02, 0.14, 0.24)
	else:
		mat.sky_top_color = def.sky_top
		mat.sky_horizon_color = def.sky_bottom
		mat.ground_bottom_color = def.sky_top.darkened(0.4)
		mat.ground_horizon_color = def.sky_bottom.darkened(0.2)
	mat.sun_angle_max = 30.0
	mat.sky_energy_multiplier = 1.15
	sky.sky_material = mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.74 if _is_arctic() else 0.85

	var quality := int(UserSettings.get_value("graphics_quality"))
	var reduced := bool(UserSettings.get_value("reduce_effects"))
	# Desktop runs Forward+, phones run the mobile renderer. Screen-space
	# effects only exist on the former, so they are asked for by name rather
	# than set blind: on mobile these properties are silently inert, which
	# hides which of them are actually doing anything.
	var rich := RenderingServer.get_current_rendering_method() == "forward_plus"

	# AgX rolls highlights off instead of clipping them, which is most of the
	# difference between "bright colours" and "lit scene" on emissive pickups.
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.08
	env.tonemap_white = 6.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.04
	env.adjustment_saturation = 1.06

	if not reduced:
		env.glow_enabled = true
		env.glow_intensity = 0.34 if _is_arctic() else 0.5
		env.glow_bloom = 0.11 if _is_arctic() else 0.15
		# Only genuinely bright surfaces should bloom; without a threshold the
		# whole image hazes over and reads as fog, not light.
		env.glow_hdr_threshold = 0.95
		env.glow_hdr_scale = 2.0
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT

	env.fog_enabled = true
	env.fog_light_color = Color(0.16, 0.42, 0.54) if _is_arctic() else def.sky_bottom
	env.fog_density = 0.006 if _is_arctic() else 0.008
	env.fog_sky_affect = 0.35
	env.fog_aerial_perspective = 0.28

	if rich and quality >= 1 and not reduced:
		# Contact shadows. Procedural primitives read as stickers floating over
		# the floor without them; this is the single biggest grounding cue.
		env.ssao_enabled = true
		env.ssao_radius = 1.1
		env.ssao_intensity = 2.2 if quality >= 2 else 1.6
		env.ssao_detail = 0.5
		env.ssao_light_affect = 0.15
	if rich and quality >= 2 and not reduced:
		env.ssil_enabled = true
		env.ssil_intensity = 0.7
		env.ssr_enabled = true
		env.ssr_max_steps = 32
		env.ssr_fade_in = 0.2
		env.ssr_fade_out = 6.0
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.012 if _is_arctic() else 0.008
		env.volumetric_fog_gi_inject = 0.6
		env.volumetric_fog_length = 96.0

	_env = WorldEnvironment.new()
	_env.environment = env
	add_child(_env)

	_light = DirectionalLight3D.new()
	_light.rotation_degrees = Vector3(-52, 34, 0) if _is_arctic() else Vector3(-58, 38, 0)
	_light.light_energy = 1.05 if _is_arctic() else 1.15
	_light.light_color = Color(0.78, 0.92, 1.0) if _is_arctic() else Color(1.0, 0.96, 0.9)
	_light.light_specular = 0.9
	_light.shadow_enabled = quality >= 1
	_light.directional_shadow_max_distance = 70.0
	# Four splits keep near-camera shadows sharp without shortening the range;
	# blending them hides the banding you otherwise see as a player runs out.
	_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS \
		if quality >= 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_light.directional_shadow_blend_splits = quality >= 2
	_light.directional_shadow_split_1 = 0.06
	_light.directional_shadow_split_2 = 0.16
	_light.directional_shadow_split_3 = 0.42
	# A real sun is not a point: giving it an angular size softens the shadow
	# with distance from the contact point, which is what sells it as sunlight.
	_light.light_angular_distance = 1.1 if quality >= 2 else 0.0
	_light.shadow_blur = 1.0
	_light.shadow_bias = 0.035
	_light.shadow_normal_bias = 1.6
	add_child(_light)

	var fill := OmniLight3D.new()
	fill.position = Vector3(0, def.radius * 0.9, 0)
	fill.omni_range = def.radius * 3.0
	fill.light_energy = 0.44 if _is_arctic() else 0.55
	fill.light_color = Color(0.18, 0.56, 0.82) if _is_arctic() else def.accent_color
	fill.shadow_enabled = false
	add_child(fill)


func _is_arctic() -> bool:
	return def != null and def.theme == "arctic"


# --- shapes ----------------------------------------------------------------

func _add_static_box(size: Vector3, pos: Vector3, color: Color, emission := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var mesh := MeshFactory.box(size, color, emission)
	body.add_child(mesh)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	body.add_child(cs)
	_static_root.add_child(body)
	return body


func _add_static_cylinder(radius: float, height: float, pos: Vector3, color: Color, emission := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var mesh := MeshFactory.cylinder(radius, height, color, emission, 32)
	body.add_child(mesh)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	cs.shape = cyl
	body.add_child(cs)
	_static_root.add_child(body)
	return body


func _build_disc() -> void:
	var body := _add_static_cylinder(def.radius, def.thickness, Vector3(0, -def.thickness * 0.5, 0), def.floor_color)
	_floor_mesh = body.get_child(0) as MeshInstance3D
	_floor_shape = (body.get_child(1) as CollisionShape3D).shape as CylinderShape3D
	if _is_arctic() and _floor_mesh != null:
		_floor_mesh.material_override = MeshFactory.ice(Color(0.66, 0.90, 0.98), 0.96)
	if not _has_hazard("shrink"):
		# When the arena shrinks, ShrinkRing draws the live rim instead.
		var rim := MeshFactory.torus(def.radius - 0.35, def.radius + 0.1, def.accent_color, 0.7)
		rim.position = Vector3(0, 0.06, 0)
		_static_root.add_child(rim)
	_add_deco_rings()
	if _is_arctic():
		_add_ice_surface_marks()


func _has_hazard(kind: String) -> bool:
	for h in def.hazards:
		if String(h.get("type", "")) == kind:
			return true
	return false


func _build_square() -> void:
	var s := def.radius * 2.0
	_add_static_box(Vector3(s, def.thickness, s), Vector3(0, -def.thickness * 0.5, 0), def.floor_color)
	for i in 4:
		var ang := TAU * i / 4.0
		var edge := MeshFactory.box(Vector3(s, 0.12, 0.5), def.accent_color, 0.6)
		edge.position = Vector3(sin(ang) * def.radius, 0.06, cos(ang) * def.radius)
		edge.rotation.y = ang
		_static_root.add_child(edge)


func _build_ring() -> void:
	var inner := def.radius * 0.45
	var segments := 28
	for i in segments:
		var a0 := TAU * i / segments
		var mid := (def.radius + inner) * 0.5
		var width := (def.radius - inner)
		var seg_len := TAU * mid / segments * 1.06
		var body := _add_static_box(
			Vector3(seg_len, def.thickness, width),
			Vector3(cos(a0) * mid, -def.thickness * 0.5, sin(a0) * mid),
			def.floor_color if i % 2 == 0 else def.floor_color.lightened(0.06))
		body.rotation.y = -a0
	var rim := MeshFactory.torus(def.radius - 0.3, def.radius + 0.1, def.accent_color, 0.6)
	rim.position = Vector3(0, 0.06, 0)
	_static_root.add_child(rim)
	var inner_rim := MeshFactory.torus(inner - 0.1, inner + 0.3, def.accent_color, 0.6)
	inner_rim.position = Vector3(0, 0.06, 0)
	_static_root.add_child(inner_rim)


func _build_cross() -> void:
	var arm := def.radius
	var w := def.radius * 0.5
	_add_static_box(Vector3(arm * 2.0, def.thickness, w), Vector3(0, -def.thickness * 0.5, 0), def.floor_color)
	_add_static_box(Vector3(w, def.thickness, arm * 2.0), Vector3(0, -def.thickness * 0.5, 0), def.floor_color)
	_add_static_cylinder(w * 0.85, def.thickness * 1.05, Vector3(0, -def.thickness * 0.5, 0), def.accent_color.darkened(0.35))
	# Four docks at the arm tips — used as delivery points by relay games.
	# Axis-aligned (0°/90°/180°/270°), deliberately NOT offset by 45°: the floor
	# built above is a plus-sign, with no collision on the diagonals between
	# arms. A 45° offset here once put every dock past the edge of the actual
	# floor, so a carrier walking toward its own dock fell through the world a
	# few metres short every single time — see docs/qa-scenarios.md.
	spawn_points.clear()
	for i in 4:
		var ang := TAU * i / 4.0
		spawn_points.append(Vector3(cos(ang) * arm * 0.55, 1.3, sin(ang) * arm * 0.55))


func _build_tiles(crumbling: bool) -> void:
	var span := int(ceil(def.radius / TILE_SIZE))
	var t := Balance.table("tuning").get("arena", {})
	for gx in range(-span, span + 1):
		for gz in range(-span, span + 1):
			var pos := Vector3(gx * TILE_SIZE, 0.0, gz * TILE_SIZE)
			if def.shape == "tiles" and Vector2(pos.x, pos.z).length() > def.radius:
				continue
			if def.shape == "grid" and (absf(pos.x) > def.radius or absf(pos.z) > def.radius):
				continue
			var tile := ArenaTile.new()
			tile.grid_x = gx
			tile.grid_z = gz
			tile.crumbles = crumbling
			tile.crumble_delay = float(t.get("tile_break_delay", 0.9))
			tile.respawn_time = float(t.get("tile_respawn", 6.0)) if crumbling else 0.0
			tile.position = pos
			_static_root.add_child(tile)
			var shade := def.floor_color.lightened(0.07) if (gx + gz) % 2 == 0 else def.floor_color
			tile.build(TILE_SIZE, def.thickness, shade)
			tile.collapsed.connect(_on_tile_collapsed)
			tiles.append(tile)


func _build_track() -> void:
	track_length = def.radius * 4.6
	lane_count = 4
	var width := def.radius * 1.4
	_add_static_box(Vector3(width, def.thickness, track_length), Vector3(0, -def.thickness * 0.5, 0), def.floor_color)
	start_z = track_length * 0.5 - 2.5
	finish_z = -track_length * 0.5 + 2.5
	for z in [start_z, finish_z]:
		var line := MeshFactory.box(Vector3(width, 0.1, 0.5), def.accent_color, 0.9)
		line.position = Vector3(0, 0.06, z)
		_static_root.add_child(line)
	spawn_points.clear()
	for i in lane_count:
		spawn_points.append(Vector3(lane_x(i), 1.3, start_z + 1.5))
	current_radius = width * 0.5


func lane_x(index: int) -> float:
	var width := def.radius * 1.4
	var step := width / float(lane_count)
	return -width * 0.5 + step * (index + 0.5)


func _build_oval() -> void:
	var inner := def.radius * 0.55
	var segments := 40
	for i in segments:
		var a0 := TAU * i / segments
		var mid := (def.radius + inner) * 0.5
		var seg_len := TAU * mid / segments * 1.08
		var body := _add_static_box(
			Vector3(seg_len, def.thickness, def.radius - inner),
			Vector3(cos(a0) * mid, -def.thickness * 0.5, sin(a0) * mid),
			def.floor_color if i % 4 < 2 else def.floor_color.lightened(0.05))
		body.rotation.y = -a0
	checkpoints.clear()
	var ring_mid := (def.radius + inner) * 0.5
	for i in 8:
		var a := TAU * i / 8.0
		checkpoints.append(Vector3(cos(a) * ring_mid, 1.0, sin(a) * ring_mid))
	var line := MeshFactory.box(Vector3(def.radius - inner, 0.1, 0.6), def.accent_color, 0.9)
	line.position = Vector3(ring_mid, 0.07, 0)
	line.rotation.y = PI * 0.5
	_static_root.add_child(line)
	spawn_points.clear()
	for i in 4:
		spawn_points.append(Vector3(ring_mid + (i % 2) * 1.8 - 0.9, 1.3, -1.4 - float(i / 2) * 2.6))


## A closed racing circuit whose centre line is r(t) = radius * (1 + wobble *
## cos(lobes * t)). Two numbers per arena is all it takes to turn one ring into
## a track with hairpins and straights, and because the line is stored the AI,
## the respawn logic and the "are you on the road" test all read the same
## geometry the road was laid on.
func _build_circuit() -> void:
	var lobes := int(def.param("lobes", 3.0))
	var wobble: float = clampf(def.param("wobble", 0.22), 0.0, 0.45)
	track_width = maxf(def.param("width", 8.0), 4.0)
	var samples := 120
	circuit_line = PackedVector3Array()
	for i in samples:
		var t := TAU * float(i) / float(samples)
		var r: float = def.radius * (1.0 + wobble * cos(float(lobes) * t))
		circuit_line.append(Vector3(cos(t) * r, 0.0, sin(t) * r))

	for i in samples:
		var a: Vector3 = circuit_line[i]
		var b: Vector3 = circuit_line[(i + 1) % samples]
		var mid := (a + b) * 0.5
		var seg := (b - a)
		# 1.35 overlap: consecutive slabs are laid on a curve, so butting them
		# end to end leaves wedge-shaped gaps a kart drops through.
		var body := _add_static_box(
			Vector3(seg.length() * 1.35, def.thickness, track_width),
			Vector3(mid.x, -def.thickness * 0.5, mid.z),
			def.floor_color if i % 8 < 4 else def.floor_color.lightened(0.045))
		body.rotation.y = -atan2(seg.z, seg.x)

	checkpoints.clear()
	var cp_count := 12
	for i in cp_count:
		var idx := int(float(i) / float(cp_count) * float(samples))
		var p: Vector3 = circuit_line[idx]
		checkpoints.append(Vector3(p.x, 1.0, p.z))

	var start: Vector3 = circuit_line[0]
	var fwd: Vector3 = (circuit_line[1] - circuit_line[samples - 1]).normalized()
	var line := MeshFactory.box(Vector3(0.7, 0.12, track_width), def.accent_color, 0.9)
	line.position = Vector3(start.x, 0.08, start.z)
	line.rotation.y = -atan2(fwd.z, fwd.x)
	_static_root.add_child(line)

	var side := Vector3(-fwd.z, 0.0, fwd.x)
	spawn_points.clear()
	for i in 4:
		# Two-by-two grid behind the line. The row gap is deliberately small:
		# it only has to read as a grid, and every metre of it is a head start
		# handed to the same two slots in every match.
		spawn_points.append(start - fwd * (2.2 + float(i / 2) * 1.6)
			+ side * (float(i % 2) * 3.0 - 1.5) + Vector3(0, 1.3, 0))


func _circuit_walls(h: float) -> void:
	var n := circuit_line.size()
	if n == 0:
		return
	for i in n:
		var a: Vector3 = circuit_line[i]
		var b: Vector3 = circuit_line[(i + 1) % n]
		var mid := (a + b) * 0.5
		var seg := b - a
		var side := Vector3(-seg.z, 0.0, seg.x).normalized()
		for s: float in [1.0, -1.0]:
			var body := _add_static_box(
				Vector3(seg.length() * 1.35, h, 0.5),
				mid + side * (track_width * 0.5 + 0.25) * s + Vector3(0, h * 0.5, 0),
				def.accent_color.darkened(0.45) if i % 8 < 4 else def.accent_color.darkened(0.15))
			body.rotation.y = -atan2(seg.z, seg.x)


func _circuit_nearest(pos: Vector3) -> Vector3:
	var n := circuit_line.size()
	if n == 0:
		return global_position
	var best: Vector3 = circuit_line[0]
	var best_d := INF
	var p := Vector3(pos.x - global_position.x, 0.0, pos.z - global_position.z)
	for i in n:
		var d: float = p.distance_squared_to(circuit_line[i])
		if d < best_d:
			best_d = d
			best = circuit_line[i]
	return global_position + best + Vector3(0, 1.2, 0)


## Lateral distance from the racing line. Sampled, so it is accurate to half a
## segment — well under the width of a kart at 120 samples.
func _circuit_offset(pos: Vector3) -> float:
	var n := circuit_line.size()
	if n == 0:
		return 0.0
	var p := Vector3(pos.x - global_position.x, 0.0, pos.z - global_position.z)
	var best := INF
	for i in n:
		var d: float = p.distance_squared_to(circuit_line[i])
		if d < best:
			best = d
	return sqrt(best)


## A point on the racing line at normalised distance `t` around the loop. Used
## by the race games to place pads and crates on the road for any shape.
func track_point(t: float) -> Vector3:
	if def.shape == "circuit" and not circuit_line.is_empty():
		var idx := int(fposmod(t, 1.0) * float(circuit_line.size())) % circuit_line.size()
		var p: Vector3 = circuit_line[idx]
		return global_position + Vector3(p.x, 0.0, p.z)
	# Oval and everything else: the mid-ring is the racing line.
	var mid: float = (def.radius + def.radius * 0.55) * 0.5
	var ang := TAU * fposmod(t, 1.0)
	return global_position + Vector3(cos(ang) * mid, 0.0, sin(ang) * mid)


func _build_pit() -> void:
	_add_static_cylinder(def.radius, def.thickness, Vector3(0, -def.thickness * 0.5, 0), def.floor_color)
	# Three tiers of ledges so a climbing game has real vertical structure.
	var tiers := 3
	for tier in range(1, tiers + 1):
		var y := float(tier) * 2.3
		var count := 6 + tier
		var r := def.radius * (0.85 - 0.16 * tier)
		for i in count:
			var ang := TAU * i / count + tier * 0.4
			var body := _add_static_box(
				Vector3(3.0, 0.5, 2.2),
				Vector3(cos(ang) * r, y, sin(ang) * r),
				def.floor_color.lightened(0.06 * tier))
			body.rotation.y = -ang
	var top := _add_static_cylinder(2.2, 0.5, Vector3(0, float(tiers) * 2.3 + 2.2, 0), def.accent_color.darkened(0.2))
	top.name = "Summit"
	var rim := MeshFactory.torus(def.radius - 0.35, def.radius + 0.1, def.accent_color, 0.7)
	rim.position = Vector3(0, 0.06, 0)
	_static_root.add_child(rim)


func _build_islands() -> void:
	_add_static_cylinder(def.radius * 0.42, def.thickness, Vector3(0, -def.thickness * 0.5, 0), def.floor_color)
	var satellites := 5
	spawn_points.clear()
	for i in satellites:
		var ang := TAU * i / satellites
		var r := def.radius * 0.78
		var y := -0.2 + float(i % 3) * 0.9
		_add_static_cylinder(def.radius * 0.26, def.thickness,
			Vector3(cos(ang) * r, y - def.thickness * 0.5, sin(ang) * r),
			def.floor_color.lightened(0.05 * (i % 3)))
		if i < 4:
			spawn_points.append(Vector3(cos(ang) * r, y + 1.3, sin(ang) * r))
	# Narrow bridges make the gaps crossable without a jump, which keeps
	# collection games readable for newcomers.
	for i in satellites:
		var ang := TAU * i / satellites
		var body := _add_static_box(Vector3(1.6, def.thickness * 0.6, def.radius * 0.42),
			Vector3(cos(ang) * def.radius * 0.5, -0.35, sin(ang) * def.radius * 0.5),
			def.accent_color.darkened(0.45))
		body.rotation.y = -ang + PI * 0.5


func _build_walls() -> void:
	var h := def.wall_height
	match def.shape:
		"square", "grid", "tiles", "crate":
			var s := def.radius * 2.0 + 1.0
			for i in 4:
				var ang := TAU * i / 4.0
				var body := _add_static_box(Vector3(s, h, 0.6),
					Vector3(sin(ang) * (def.radius + 0.3), h * 0.5, cos(ang) * (def.radius + 0.3)),
					def.accent_color.darkened(0.5))
				body.rotation.y = ang
		"track":
			var w := def.radius * 0.7 + 0.4
			for sx in [-1.0, 1.0]:
				_add_static_box(Vector3(0.6, h, track_length),
					Vector3(w * sx, h * 0.5, 0), def.accent_color.darkened(0.5))
		"oval":
			_ring_wall(def.radius + 0.35, h, 40)
			_ring_wall(def.radius * 0.55 - 0.35, h, 28)
		"circuit":
			_circuit_walls(h)
		_:
			_ring_wall(def.radius + 0.3, h, 36)


func _ring_wall(radius: float, h: float, segments: int) -> void:
	var seg_len := TAU * radius / segments * 1.05
	for i in segments:
		var ang := TAU * i / segments
		var body := _add_static_box(Vector3(seg_len, h, 0.5),
			Vector3(cos(ang) * radius, h * 0.5, sin(ang) * radius),
			def.accent_color.darkened(0.5))
		body.rotation.y = -ang


func _add_deco_rings() -> void:
	for i in 3:
		var r := def.radius * (0.32 + 0.22 * i)
		var ring := MeshFactory.torus(r - 0.06, r + 0.06, def.floor_color.lightened(0.16))
		ring.position = Vector3(0, 0.03, 0)
		_static_root.add_child(ring)


func _add_arctic_set_dressing() -> void:
	_arctic_water_layers.clear()
	_arctic_waves.clear()
	_arctic_floes.clear()
	_arctic_shrink_followers.clear()
	var ocean := MeshFactory.plane(Vector2(def.radius * 18.0, def.radius * 18.0), Color(0.015, 0.12, 0.22))
	ocean.name = "ArcticOcean"
	ocean.position = Vector3(0, -0.82, 0)
	ocean.material_override = MeshFactory.water(Color(0.005, 0.11, 0.22), 0.94)
	_static_root.add_child(ocean)
	_arctic_water_layers.append({"node": ocean, "base": ocean.position, "speed": 0.10, "phase": 0.0})

	var deep_patch := MeshFactory.plane(Vector2(def.radius * 16.0, def.radius * 16.0), Color(0.01, 0.08, 0.16))
	deep_patch.name = "ArcticOceanDepth"
	deep_patch.position = Vector3(0, -0.815, 0)
	deep_patch.rotation_degrees = Vector3(0, 18, 0)
	deep_patch.material_override = MeshFactory.transparent(Color(0.0, 0.04, 0.09), 0.22)
	_static_root.add_child(deep_patch)
	_arctic_water_layers.append({"node": deep_patch, "base": deep_patch.position, "speed": -0.07, "phase": 1.4})

	var far_water := MeshFactory.plane(Vector2(def.radius * 28.0, def.radius * 28.0), Color(0.0, 0.07, 0.14))
	far_water.name = "ArcticFarWater"
	far_water.position = Vector3(0, -0.86, 0)
	far_water.rotation_degrees = Vector3(0, -11, 0)
	far_water.material_override = MeshFactory.water(Color(0.0, 0.075, 0.15), 0.98)
	_static_root.add_child(far_water)
	_arctic_water_layers.append({"node": far_water, "base": far_water.position, "speed": 0.045, "phase": 2.7})

	var ocean_glow := MeshFactory.plane(Vector2(def.radius * 5.0, def.radius * 5.0), Color(0.05, 0.46, 0.62))
	ocean_glow.name = "ArcticOceanInnerGlow"
	ocean_glow.position = Vector3(0, -0.9, 0)
	ocean_glow.material_override = MeshFactory.transparent(Color(0.08, 0.60, 0.82), 0.08)
	_static_root.add_child(ocean_glow)

	for i in 54:
		var ang := TAU * float(i) / 54.0
		var r := def.radius * (1.20 + 2.5 * float(i % 9) / 8.0)
		var wave := MeshFactory.box(Vector3(1.7 + 0.55 * float(i % 4), 0.022, 0.05), Color(0.68, 0.93, 1.0))
		wave.name = "ArcticWave%d" % i
		wave.position = Vector3(cos(ang) * r, -0.53 + 0.025 * sin(float(i)), sin(ang) * r)
		wave.rotation.y = -ang + 0.18 * sin(float(i) * 1.9)
		wave.material_override = MeshFactory.transparent(Color(0.72, 0.97, 1.0), 0.56)
		_static_root.add_child(wave)
		_arctic_waves.append({"node": wave, "base": wave.position, "angle": ang, "phase": float(i) * 0.37})

	var floe_rim := MeshFactory.torus(def.radius - 0.28, def.radius + 0.34, Color(0.78, 0.95, 1.0), 0.22)
	floe_rim.name = "IceFloeRim"
	floe_rim.position = Vector3(0, 0.12, 0)
	floe_rim.material_override = MeshFactory.ice(Color(0.76, 0.94, 1.0), 0.98)
	_static_root.add_child(floe_rim)
	_arctic_shrink_followers.append(floe_rim)

	var snow_lip := MeshFactory.torus(def.radius - 0.05, def.radius + 0.12, Color(1.0, 1.0, 0.96), 0.18)
	snow_lip.name = "SnowLip"
	snow_lip.position = Vector3(0, 0.18, 0)
	_static_root.add_child(snow_lip)
	_arctic_shrink_followers.append(snow_lip)

	var melt_edge := MeshFactory.torus(def.radius + 0.18, def.radius + 0.62, Color(0.45, 0.9, 1.0), 0.32)
	melt_edge.name = "MeltingWaterEdge"
	melt_edge.position = Vector3(0, 0.02, 0)
	melt_edge.material_override = MeshFactory.water(Color(0.18, 0.72, 0.95), 0.58)
	_static_root.add_child(melt_edge)
	_arctic_shrink_followers.append(melt_edge)

	var chunks := 40
	for i in chunks:
		var ang := TAU * float(i) / float(chunks)
		var r := def.radius + 0.5 + 0.32 * sin(float(i) * 1.7)
		var chunk := ArenaHazards.BreakableIceBarrier.new()
		chunk.name = "IceBarrier%d" % i
		chunk.position = Vector3(cos(ang) * r, 0.2, sin(ang) * r)
		chunk.rotation_degrees = Vector3(-4.0 + float(i % 5) * 2.0, -rad_to_deg(ang), 3.0 * sin(float(i)))
		chunk.build(0.86 + 0.22 * float(i % 3), def.accent_color.lightened(0.10))
		_static_root.add_child(chunk)
		_hazards.append(chunk)

	for i in 20:
		var ang := TAU * float(i) / 20.0 + 0.11
		var r := def.radius * (1.42 + 0.48 * float(i % 6) / 5.0)
		var floe := MeshFactory.ice_chunk(0.45 + 0.12 * float(i % 4), Color(0.82, 0.96, 1.0))
		floe.name = "FloatingIce%d" % i
		floe.position = Vector3(cos(ang) * r, -0.43, sin(ang) * r)
		floe.rotation_degrees = Vector3(0, rad_to_deg(-ang) + float(i * 13), 0)
		floe.scale = Vector3(1.5 + 0.18 * float(i % 2), 0.42, 0.7 + 0.12 * float(i % 3))
		_static_root.add_child(floe)
		_arctic_floes.append({"node": floe, "base": floe.position, "phase": float(i) * 0.53})

	for i in 10:
		var ang := TAU * float(i) / 10.0 + 0.2
		var r := def.radius * (2.08 + 0.12 * float(i % 3))
		var berg := MeshFactory.ice_chunk(0.9 + 0.22 * float(i % 3), Color(0.78, 0.94, 1.0))
		berg.name = "BackgroundIceberg%d" % i
		berg.position = Vector3(cos(ang) * r, -0.35, sin(ang) * r)
		berg.rotation_degrees = Vector3(0, rad_to_deg(-ang) + float(i * 21), 0)
		berg.scale = Vector3(1.8 + 0.15 * float(i % 2), 0.9, 1.0)
		_static_root.add_child(berg)


func _add_ice_surface_marks() -> void:
	var crack_color := Color(0.42, 0.70, 0.82, 0.55)
	for i in 26:
		var strip := MeshFactory.box(Vector3(1.2 + 0.55 * float(i % 4), 0.026, 0.045), crack_color)
		var r := def.radius * (0.12 + 0.032 * float(i))
		var ang := TAU * float(i) / 26.0 + 0.3
		strip.position = Vector3(cos(ang) * r, 0.08, sin(ang) * r)
		strip.rotation.y = -ang + 0.35 * sin(float(i))
		strip.material_override = MeshFactory.transparent(Color(0.25, 0.66, 0.82), 0.5)
		_static_root.add_child(strip)
	for i in 16:
		var patch := MeshFactory.box(Vector3(1.8 + 0.35 * float(i % 3), 0.028, 0.42 + 0.08 * float(i % 2)), Color(0.98, 1.0, 0.98))
		var r := def.radius * (0.24 + 0.06 * float(i % 6))
		var ang := TAU * float(i) / 16.0 + 0.55
		patch.position = Vector3(cos(ang) * r, 0.105, sin(ang) * r)
		patch.rotation.y = -ang + 0.6
		patch.material_override = MeshFactory.transparent(Color(0.98, 1.0, 0.98), 0.36)
		_static_root.add_child(patch)
	for i in 18:
		var scratch := MeshFactory.box(Vector3(0.9 + 0.18 * float(i % 4), 0.018, 0.026), Color(0.78, 0.93, 0.98))
		var r := def.radius * (0.16 + 0.04 * float(i % 10))
		var ang := TAU * float(i) / 18.0 + 0.9
		scratch.position = Vector3(cos(ang) * r, 0.13, sin(ang) * r)
		scratch.rotation.y = -ang + 1.1
		scratch.material_override = MeshFactory.transparent(Color(0.86, 0.98, 1.0), 0.5)
		_static_root.add_child(scratch)


# --- hazards ---------------------------------------------------------------

func _build_hazards() -> void:
	var t := Balance.table("tuning").get("arena", {})
	for h in def.hazards:
		var kind := String(h.get("type", ""))
		match kind:
			"sweeper":
				var count := int(h.get("count", 2))
				for i in count:
					var s := ArenaHazards.Sweeper.new()
					s.speed = float(h.get("speed", 1.0)) * (1.0 if i % 2 == 0 else -1.0)
					s.power = float(t.get("hazard_knockback", 15.0))
					add_child(s)
					s.build(def.accent_color, float(h.get("length", def.radius * 0.8)), float(h.get("height", 0.9)))
					s.rotation.y = TAU * i / float(maxi(count, 1))
					_base_hazard_speed[s.get_instance_id()] = s.speed
					_hazards.append(s)
			"bumper":
				var count := int(h.get("count", 4))
				for i in count:
					var b := ArenaHazards.Bumper.new()
					b.power = float(h.get("power", 17.0))
					var ang := TAU * i / float(count) + 0.4
					var r := def.radius * (0.3 if i % 2 == 0 else 0.62)
					b.position = Vector3(cos(ang) * r, 0, sin(ang) * r)
					add_child(b)
					b.build(def.accent_color, float(h.get("radius", 1.1)))
					_hazards.append(b)
			"pillars":
				var count := int(h.get("count", 6))
				for i in count:
					var ang := TAU * i / float(count) + 0.7
					var r := def.radius * (0.38 if i % 2 == 0 else 0.68)
					_add_static_cylinder(float(h.get("radius", 1.1)), float(h.get("height", 2.4)),
						Vector3(cos(ang) * r, float(h.get("height", 2.4)) * 0.5, sin(ang) * r),
						def.accent_color.darkened(0.35))
			"hurdles":
				var rows := int(h.get("rows", 6))
				for row in range(1, rows + 1):
					var z := start_z - track_length * (float(row) / float(rows + 1))
					for lane in lane_count:
						if (row + lane) % 4 == 0:
							continue  # a gap per row keeps lanes non-identical
						_add_static_box(Vector3(def.radius * 0.3, float(h.get("height", 0.85)), 0.35),
							Vector3(lane_x(lane), float(h.get("height", 0.85)) * 0.5, z),
							def.accent_color)
			"shrink":
				_shrink = ArenaHazards.ShrinkRing.new()
				_shrink.start_delay = float(h.get("start_delay", 18.0))
				_shrink.rate = float(h.get("rate", 0.3))
				_shrink.min_radius = float(h.get("min_radius", 5.0))
				add_child(_shrink)
				_shrink.build(def.accent_color, def.radius)
				_shrink.radius_changed.connect(_on_radius_changed)
				_hazards.append(_shrink)
			"rising":
				_water = ArenaHazards.RisingWater.new()
				_water.speed = float(h.get("speed", 0.4))
				add_child(_water)
				_water.build(def.accent_color, def.radius, float(h.get("start_y", -6.0)))
				_water.submerged.connect(func(f): fighter_submerged.emit(f))
				_base_hazard_speed[_water.get_instance_id()] = _water.speed
				_hazards.append(_water)


func _on_radius_changed(r: float) -> void:
	current_radius = r
	# Move the physical edge with the painted one, otherwise players keep
	# standing on floor that visually no longer exists.
	if _floor_shape != null:
		_floor_shape.radius = r
	if _floor_mesh != null and is_instance_valid(_floor_mesh):
		var k := r / maxf(def.radius, 0.001)
		_floor_mesh.scale = Vector3(k, 1.0, k)
		for n in _arctic_shrink_followers:
			if is_instance_valid(n):
				n.scale = Vector3(k, 1.0, k)
	radius_changed.emit(r)


func _tick_arctic_water(delta: float) -> void:
	if not _is_arctic():
		return
	_arctic_time += delta
	for entry in _arctic_water_layers:
		var n: Node3D = entry["node"]
		if not is_instance_valid(n):
			continue
		var base: Vector3 = entry["base"]
		var phase := float(entry["phase"])
		n.position = base + Vector3(
			sin(_arctic_time * 0.33 + phase) * 0.22,
			sin(_arctic_time * 0.82 + phase) * 0.026,
			cos(_arctic_time * 0.29 + phase) * 0.22)
		n.rotation.y += float(entry["speed"]) * delta
	for entry in _arctic_waves:
		var n: Node3D = entry["node"]
		if not is_instance_valid(n):
			continue
		var base: Vector3 = entry["base"]
		var phase := float(entry["phase"])
		n.position = base + Vector3(0, sin(_arctic_time * 2.1 + phase) * 0.055, 0)
		n.scale.x = 1.0 + sin(_arctic_time * 1.7 + phase) * 0.18
	for entry in _arctic_floes:
		var n: Node3D = entry["node"]
		if not is_instance_valid(n):
			continue
		var base: Vector3 = entry["base"]
		var phase := float(entry["phase"])
		n.position = base + Vector3(
			sin(_arctic_time * 0.42 + phase) * 0.18,
			sin(_arctic_time * 1.2 + phase) * 0.035,
			cos(_arctic_time * 0.38 + phase) * 0.18)
		n.rotation.y += sin(_arctic_time * 0.6 + phase) * delta * 0.08


func _on_tile_collapsed(tile: ArenaTile) -> void:
	tile_collapsed.emit(tile)
