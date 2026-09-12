extends Node3D
## One instanced weather draw; no per-drop nodes or physics bodies.

var biome := 0
var arena: Arena
var bolt: Node3D
var thunder: AudioStreamPlayer
var countdown := 7.0
var flash_left := 0.0
var thunder_delay := -1.0
var strikes := 0
var base_energy := 1.0


func build(a: Arena, kind: int, volcano := Vector3.ZERO) -> void:
	name = "Weather"
	arena = a
	biome = kind
	base_energy = arena._light.light_energy
	var rain := kind == 4
	var ash := kind == 3
	var node := MultiMeshInstance3D.new()
	node.name = "Rain" if rain else ("Ash" if ash else "Snow")
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.025, 0.65) if rain else Vector2.ONE * (0.09 if ash else 0.12)
	var material := ShaderMaterial.new()
	material.shader = load("res://src/arenas/racing_precipitation.gdshader")
	material.set_shader_parameter("speed", 22.0 if rain else (1.1 if ash else 1.8))
	material.set_shader_parameter("tint", Color(0.69, 0.8, 0.87, 0.3) if rain else (Color(0.38, 0.35, 0.33, 0.7) if ash else Color(0.92, 0.97, 1.0, 0.8)))
	mesh.material = material
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = mesh
	instances.instance_count = 3200 if rain else 1500
	var rng := RandomNumberGenerator.new()
	rng.seed = 2084 + kind
	for i in instances.instance_count:
		instances.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(rng.randf_range(-110, 110), 0, rng.randf_range(-110, 110))))
		instances.set_instance_custom_data(i, Color(rng.randf(), rng.randf(), 0, 1))
	node.multimesh = instances
	node.custom_aabb = AABB(Vector3(-125, -15, -125), Vector3(250, 80, 250))
	add_child(node)
	if ash:
		_make_plume(volcano)
	if rain:
		_make_lightning()
	set_process(rain)


func _make_plume(origin: Vector3) -> void:
	var plume := MultiMeshInstance3D.new()
	plume.name = "VolcanoPlume"
	plume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := QuadMesh.new()
	mesh.size = Vector2(9, 9)
	var material := ShaderMaterial.new()
	material.shader = load("res://src/arenas/racing_precipitation.gdshader")
	material.set_shader_parameter("speed", -1.4)
	material.set_shader_parameter("plume", true)
	material.set_shader_parameter("tint", Color(0.15, 0.14, 0.14, 0.28))
	mesh.material = material
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = mesh
	instances.instance_count = 70
	for i in instances.instance_count:
		var p := origin + Vector3(sin(i * 2.4) * 3, 0, cos(i * 2.4) * 3)
		instances.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
		instances.set_instance_custom_data(i, Color(float(i) / instances.instance_count, fmod(i * 0.618, 1.0), 0, 1))
	plume.multimesh = instances
	plume.custom_aabb = AABB(origin - Vector3(12, 12, 12), Vector3(45, 90, 45))
	add_child(plume)


func _make_lightning() -> void:
	bolt = Node3D.new()
	bolt.name = "Lightning"
	bolt.position = Vector3(58, 0, -48)
	add_child(bolt)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("d5e6ff")
	material.emission_enabled = true
	material.emission = Color("9fc3ff")
	material.emission_energy_multiplier = 2.0
	var previous := Vector3(0, 42, 0)
	for i in 10:
		var next := Vector3(sin(i * 7.13) * 2.4, 38.0 - i * 4.0, cos(i * 4.71) * 1.2)
		_segment(previous, next, material)
		if i == 3 or i == 6:
			_segment(next, next + Vector3(5, -5, 2), material)
		previous = next
	bolt.visible = false
	thunder = AudioStreamPlayer.new()
	thunder.name = "Thunder"
	thunder.bus = "SFX"
	thunder.volume_db = -14.0
	add_child(thunder)
	if AudioManager.enabled:
		var rumble := Synth.voice({"wave": Synth.Wave.NOISE, "dur": 2.5, "attack": 0.04, "release": 1.8, "gain": 0.5})
		var filtered := 0.0
		for i in rumble.size():
			filtered = lerpf(filtered, rumble[i], 0.055)
			rumble[i] = filtered
		thunder.stream = Synth.to_stream(rumble)


func _segment(a: Vector3, b: Vector3, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.07
	mesh.bottom_radius = 0.09
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 5
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bolt.add_child(node)
	node.position = (a + b) * 0.5
	node.quaternion = Quaternion(Vector3.UP, (b - a).normalized())


func _process(delta: float) -> void:
	if AudioManager.is_suspended():
		if thunder != null: thunder.stop()
		return
	countdown -= delta
	if countdown <= 0.0:
		trigger_lightning()
	if flash_left > 0.0:
		flash_left = maxf(0.0, flash_left - delta)
		var reduced: bool = UserSettings.get_value("reduce_flashes")
		bolt.visible = not reduced and flash_left > 0.0
		arena._light.light_energy = base_energy + (0.25 * flash_left / 0.3 if not reduced else 0.0)
	if thunder_delay >= 0.0:
		thunder_delay -= delta
		if thunder_delay < 0.0 and thunder.stream != null:
			thunder.play()


func trigger_lightning() -> void:
	strikes += 1
	countdown = 9.0 + float(strikes % 3) * 2.0
	flash_left = 0.3
	thunder_delay = 0.8
	bolt.visible = not bool(UserSettings.get_value("reduce_flashes"))


func _exit_tree() -> void:
	if is_instance_valid(arena) and is_instance_valid(arena._light):
		arena._light.light_energy = base_energy
