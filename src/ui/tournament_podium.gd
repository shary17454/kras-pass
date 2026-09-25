class_name TournamentPodium
extends TextureRect
## One bounded 3D viewport, stopped after its short celebration.

var _viewport: SubViewport
var _models: Array[Node3D] = []
var _bases: Array[float] = []
var _elapsed := 0.0
var _motion := false


func setup(session: TournamentSession) -> void:
	custom_minimum_size = Vector2(0, 260)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if DisplayServer.get_name() == "headless":
		return
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1080, 400)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	texture = _viewport.get_texture()
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 12.5
	camera.position = Vector3(0, 6, 13)
	_viewport.add_child(camera)
	camera.look_at(Vector3(0, 1.9, 0))
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	_viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.light_energy = 1.3
	_viewport.add_child(light)
	var rows := session.rows()
	for i in mini(3, rows.size()):
		var row: Dictionary = rows[i]
		var player := session.players[int(row["slot"])]
		var height := 1.8 - float(int(row["rank"]) - 1) * 0.35
		var x: float = [0.0, -3.5, 3.5][i]
		var base := MeshFactory.cylinder(1.4, height, player.color().darkened(0.45))
		base.position = Vector3(x, height * 0.5, 0)
		_viewport.add_child(base)
		var model := MeshFactory.character_body(player.character_with_cosmetics())
		model.position = Vector3(x, height, 0)
		model.rotation.y = PI
		_viewport.add_child(model)
		_models.append(model)
		_bases.append(height)
		var rank := Label3D.new()
		rank.text = str(row["rank"])
		rank.font_size = 96
		rank.pixel_size = 0.008
		rank.no_depth_test = true
		rank.position = Vector3(x, height * 0.55, 1.4)
		_viewport.add_child(rank)
	var cup := Node3D.new()
	cup.position = Vector3(0, 0.4, 2.4)
	_viewport.add_child(cup)
	for part in [MeshFactory.cylinder(0.45, 0.12, Color.GOLD), MeshFactory.cylinder(0.12, 0.5, Color.GOLD), MeshFactory.sphere(0.4, Color.GOLD)]:
		part.position.y = cup.get_child_count() * 0.3
		cup.add_child(part)
	_motion = not bool(UserSettings.get_value("reduce_effects")) and not bool(UserSettings.get_value("reduce_flashes"))
	if _motion:
		_add_confetti(session.seed_value)
	else:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		set_process(false)


func _add_confetti(rng_seed: int) -> void:
	var particles := GPUParticles3D.new()
	particles.amount = 64
	particles.lifetime = 2.8
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.use_fixed_seed = true
	particles.seed = rng_seed
	particles.position = Vector3(0, 4.5, 0)
	particles.visibility_aabb = AABB(Vector3(-7, -5, -4), Vector3(14, 12, 8))
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3.UP
	material.spread = 80
	material.initial_velocity_min = 1
	material.initial_velocity_max = 3
	material.gravity = Vector3(0, -2, 0)
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	material.emission_box_extents = Vector3(5, 0.5, 1)
	var colors := Gradient.new()
	colors.colors = PackedColorArray([Color.GOLD, Color.CORAL, Color.TURQUOISE, Color.WHITE])
	colors.offsets = PackedFloat32Array([0, 0.33, 0.66, 1])
	var ramp := GradientTexture1D.new()
	ramp.gradient = colors
	material.color_initial_ramp = ramp
	particles.process_material = material
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.08, 0.15)
	var surface := StandardMaterial3D.new()
	surface.vertex_color_use_as_albedo = true
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	surface.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = surface
	particles.draw_pass_1 = mesh
	_viewport.add_child(particles)


func _process(delta: float) -> void:
	if _viewport == null or not _motion:
		return
	_elapsed += delta
	for i in _models.size():
		_models[i].position.y = _bases[i] + maxf(0, sin(_elapsed * 7.0 + i * 0.7)) * 0.18
	if _elapsed >= 4.0:
		for i in _models.size():
			_models[i].position.y = _bases[i]
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		set_process(false)
