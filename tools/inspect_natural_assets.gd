extends SceneTree


func _initialize() -> void:
	for path in ["res://assets/natural/pine_mobile.glb", "res://assets/natural/rock_moss_set_01/rock_moss_set_01_2k.gltf"]:
		var packed: PackedScene = load(path)
		var root := packed.instantiate()
		for child in root.find_children("*", "MeshInstance3D", true, false):
			var triangles := 0
			for surface in child.mesh.get_surface_count():
				triangles += child.mesh.surface_get_array_index_len(surface) / 3
			print(child.name, " bounds=", child.mesh.get_aabb(), " triangles=", triangles)
		root.free()
	quit()
