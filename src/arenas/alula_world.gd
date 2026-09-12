extends "res://src/arenas/racing_biome.gd"
## Original sandstone landscape inspired by AlUla, not a geographic reconstruction.
const MESAS := [
    Vector4(-145, -90, 29, 68), Vector4(-115, -145, 35, 76),
    Vector4(-30, -135, 24, 60), Vector4(45, -140, 31, 73),
    Vector4(145, -100, 30, 82), Vector4(140, -20, 24, 64),
    Vector4(130, 70, 33, 78), Vector4(60, 145, 32, 72),
    Vector4(-35, 150, 25, 63), Vector4(-140, 105, 30, 80),
    Vector4(-155, 10, 23, 68), Vector4(-30, 12, 17, 48),
    Vector4(32, 40, 13, 42), Vector4(5, -48, 15, 52)
]


func ground_height(x: float, z: float) -> float:
    var nearest := _nearest(x, z)
    var clearance := smoothstep(arena.track_width * 0.5 + 10.0, 32.0, nearest.x)
    var mountain := 0.0
    for mesa: Vector4 in MESAS:
        var dx := (x - mesa.x) / mesa.z
        var dz := (z - mesa.y) / (mesa.z * (0.55 + absf(sin(mesa.x)) * 0.8))
        var angle := atan2(dz, dx)
        var r := Vector2(dx, dz).length()
        r += sin(angle * 3.0 + mesa.x) * 0.18 + sin(angle * 7.0 + mesa.y) * 0.07 + sin(angle * 15.0) * 0.025
        var profile := 1.0 - smoothstep(0.0, 1.8, r)
        var crown := 0.9 + sin(x * 0.18 + z * 0.11) * 0.055 + noise.get_noise_2d(x * 2.0, z * 2.0) * 0.14
        mountain = maxf(mountain, profile * 5.0 * crown)
    return nearest.y - 0.08 + clearance * (mountain + noise.get_noise_2d(x, z) * 1.4)


func _lighting() -> void:
    super._lighting()
    var env := arena._env.environment
    var sky := env.sky.sky_material as ProceduralSkyMaterial
    sky.sky_top_color = Color("455a69")
    sky.sky_horizon_color = Color("a3a9aa")
    env.fog_light_color = Color("9b9e9d")
    env.fog_density = 0.0012
    env.ambient_light_energy = 0.48
    arena._light.light_color = Color("e3e8ec")
    arena._light.light_energy = 1.35
    var clouds := ShaderMaterial.new()
    clouds.shader = load("res://src/arenas/alula_clouds.gdshader")
    env.sky.sky_material = clouds


func _add_distant_rocks() -> void:
    pass


func _dress() -> void:
    var formations := Node3D.new()
    formations.name = "SandstoneFormations"
    add_child(formations)
    var material := ShaderMaterial.new()
    material.shader = load("res://src/arenas/alula_sandstone.gdshader")
    var path := ROOT + "rock_moss_set_01/textures/rock_moss_set_01_"
    material.set_shader_parameter("scan_color", load(path + "diff_2k.jpg"))
    material.set_shader_parameter("scan_normal", load(path + "nor_gl_2k.jpg"))
    material.set_shader_parameter("detail", load(ROOT + "aerial_rocks_01/aerial_rocks_01_diff_2k.jpg"))
    var shapes: Array[Shape3D] = []
    for mesh in _rock_meshes:
        shapes.append(mesh.create_trimesh_shape())
    for i in MESAS.size():
        var mesa: Vector4 = MESAS[i]
        var distance := _nearest(mesa.x, mesa.y).x
        var width := minf(mesa.z * 1.6, (distance - arena.track_width * 0.5 - 7.0) * 1.35)
        if width < 8.0:
            continue
        var mesh := _rock_meshes[i % _rock_meshes.size()]
        var bounds := mesh.get_aabb()
        var cliff := MeshInstance3D.new()
        cliff.name = "ScannedCliff%d" % i
        cliff.mesh = mesh
        cliff.material_override = material
        var dimensions := Vector3(width, mesa.w * (0.7 if i > 10 else 1.0), width * 0.82)
        cliff.basis = Basis(Vector3.UP, i * 2.4).scaled(dimensions / bounds.size)
        var foot := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
        cliff.position = Vector3(mesa.x, ground_height(mesa.x, mesa.y) - dimensions.y * 0.24, mesa.y) - cliff.basis * foot
        formations.add_child(cliff)
        var body := StaticBody3D.new()
        body.name = "CliffCollision%d" % i
        body.transform = cliff.transform
        var collision := CollisionShape3D.new()
        collision.shape = shapes[i % shapes.size()]
        body.add_child(collision)
        formations.add_child(body)
    var rng := RandomNumberGenerator.new()
    rng.seed = 51839
    for variant in _rock_meshes.size():
        var transforms: Array[Transform3D] = []
        var mesh := _rock_meshes[variant]
        var bounds := mesh.get_aabb()
        for i in 24:
            var x := rng.randf_range(-190, 190)
            var z := rng.randf_range(-180, 180)
            if _nearest(x, z).x < arena.track_width * 0.5 + 10:
                continue
            var size := rng.randf_range(0.45, 2.8) / bounds.size.length()
            var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size)
            transforms.append(Transform3D(basis, Vector3(x, ground_height(x, z) - bounds.position.y * size - 0.1, z)))
        _instances(mesh, transforms, "SandstoneRubble%d" % variant)
        get_node("SandstoneRubble%d" % variant).material_override = material


func _water() -> void:
    # Rain-darkened ground and wet asphalt, without a fictitious permanent river.
    pass
