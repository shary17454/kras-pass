extends RefCounted


func run(t: TestHarness) -> void:
	t.suite("shared immutable sphere geometry")
	MeshFactory.clear_cache()
	var first := MeshFactory.sphere(0.6, Color.RED, 1.0)
	var second := MeshFactory.sphere(0.6, Color.BLUE)
	var authored := SphereMesh.new()
	authored.radius = 0.6
	authored.height = 1.2
	t.ok(first != second, "instances remain independently owned")
	t.ok(first.mesh == second.mesh, "identical sphere dimensions reuse geometry across colors")
	t.ok(first.material_override != second.material_override, "per-instance material styles remain independent")
	t.equal(first.mesh.radius, authored.radius, "shared geometry retains the engine's authored radius")
	t.equal(first.mesh.height, authored.height, "shared geometry retains the engine's authored diameter")
	t.equal(first.mesh.radial_segments, 36, "radial detail is not reduced")
	t.equal(first.mesh.rings, 18, "ring detail is not reduced")
	var different := MeshFactory.sphere(0.6000000001, Color.RED)
	t.ok(different.mesh != first.mesh, "nearby radii do not collide in a rounded cache key")
	first.scale = Vector3(2, 3, 4)
	t.equal(second.scale, Vector3.ONE, "instance scaling cannot resize another sphere")
	var crate := MeshFactory.crate(1.4, Color("#7d6a55"), Color("#ff8a3d"))
	var bolts: Array[MeshInstance3D] = []
	for child in crate.get_children():
		if child is MeshInstance3D and child.mesh is SphereMesh:
			bolts.append(child)
	t.equal(bolts.size(), 4, "crate still renders all four detailed bolts")
	for index in range(1, bolts.size()):
		t.ok(bolts[index].mesh == bolts[0].mesh, "crate bolts share geometry without losing their transforms")
	var old_mesh: Mesh = first.mesh
	MeshFactory.clear_cache()
	t.ok(is_instance_valid(old_mesh), "clearing unused caches preserves live sphere geometry")
	var after_clear := MeshFactory.sphere(0.6, Color.RED)
	t.ok(after_clear.mesh != old_mesh, "a cleared cache cannot resurrect the previous resource")
	for node in [first, second, different, crate, after_clear]:
		node.free()
	MeshFactory.clear_cache()
