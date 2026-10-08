extends RefCounted


func run(t: TestHarness, _host: Node) -> void:
	t.suite("batched ice surface geometry")
	var rendered := DisplayServer.get_name() != "headless"
	print("ICE_MARK_SCOPE=", "rendered-instance-transforms" if rendered else "authored-data-and-dummy-instance-schema")
	for radius in [12.0, 19.0]:
		var arena := Arena.new()
		arena.def = ArenaDef.new()
		arena.def.radius = radius
		arena._static_root = Node3D.new()
		arena.add_child(arena._static_root)
		arena._add_ice_surface_marks()
		var definitions: Dictionary = arena._ice_surface_mark_batches()
		var actual: Array[Dictionary] = []
		for node in arena._static_root.get_children():
			if node is MeshInstance3D:
				actual.append({"mesh": node.mesh, "material": node.material_override,
					"transform": node.transform, "shadow": node.cast_shadow})
			elif node is MultiMeshInstance3D:
				var transforms: Array = []
				for batch in definitions.values():
					if batch.mesh == node.multimesh.mesh and batch.material == node.material_override:
						transforms = batch.transforms
				t.equal(node.multimesh.instance_count, transforms.size(), "renderer instance count matches the authored batch")
				for index in node.multimesh.instance_count:
					var placement: Transform3D = node.multimesh.get_instance_transform(index) if rendered else transforms[index]
					actual.append({"mesh": node.multimesh.mesh, "material": node.material_override,
						"transform": node.transform * placement,
						"shadow": node.cast_shadow})
			else:
				t.ok(false, "ice surface dressing has no physics or unrelated nodes")
		t.equal(arena._static_root.get_child_count(), 14, "sixty authored marks use fourteen geometry/material batches")
		t.equal(actual.size(), 60, "batching preserves every authored ice mark")
		for expected in _authored_marks(radius):
			var matches := 0
			for mark in actual:
				if mark.mesh == expected.mesh and mark.material == expected.material \
						and mark.transform.is_equal_approx(expected.transform) \
						and mark.shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
					matches += 1
			t.equal(matches, 1, "original mesh, material, transform and shadow policy appear exactly once")
		arena.free()


func _authored_marks(radius: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in 26:
		var node := MeshFactory.box(Vector3(1.2 + 0.55 * float(i % 4), 0.026, 0.045), Color(0.42, 0.70, 0.82, 0.55))
		var r := radius * (0.12 + 0.032 * float(i))
		var angle := TAU * float(i) / 26.0 + 0.3
		node.position = Vector3(cos(angle) * r, 0.08, sin(angle) * r)
		node.rotation.y = -angle + 0.35 * sin(float(i))
		node.material_override = MeshFactory.transparent(Color(0.25, 0.66, 0.82), 0.5)
		_capture(result, node)
	for i in 16:
		var node := MeshFactory.box(Vector3(1.8 + 0.35 * float(i % 3), 0.028, 0.42 + 0.08 * float(i % 2)), Color(0.98, 1.0, 0.98))
		var r := radius * (0.24 + 0.06 * float(i % 6))
		var angle := TAU * float(i) / 16.0 + 0.55
		node.position = Vector3(cos(angle) * r, 0.105, sin(angle) * r)
		node.rotation.y = -angle + 0.6
		node.material_override = MeshFactory.transparent(Color(0.98, 1.0, 0.98), 0.36)
		_capture(result, node)
	for i in 18:
		var node := MeshFactory.box(Vector3(0.9 + 0.18 * float(i % 4), 0.018, 0.026), Color(0.78, 0.93, 0.98))
		var r := radius * (0.16 + 0.04 * float(i % 10))
		var angle := TAU * float(i) / 18.0 + 0.9
		node.position = Vector3(cos(angle) * r, 0.13, sin(angle) * r)
		node.rotation.y = -angle + 1.1
		node.material_override = MeshFactory.transparent(Color(0.86, 0.98, 1.0), 0.5)
		_capture(result, node)
	return result


func _capture(result: Array[Dictionary], node: MeshInstance3D) -> void:
	result.append({"mesh": node.mesh, "material": node.material_override, "transform": node.transform})
	node.free()
