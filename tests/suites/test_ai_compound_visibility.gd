extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("AI compound visual cues")
	var root := Node3D.new()
	host.add_child(root)
	root.position.y = 1000.0
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 1, 10)
	camera.look_at(root.global_position + Vector3.UP, Vector3.UP)
	camera.set_perspective(90, 0.1, 50)
	camera.cull_mask = 1
	var context := MatchContext.new()
	context.config = MatchConfig.build("ring_rumble", ["fanoos"], 0, 1, 119)
	context.observation_camera = camera
	var brain := AIBrain.new()
	brain.configure(0, context, 3, 119)
	var actor := Node3D.new()
	root.add_child(actor)
	actor.position = Vector3(0, 1, 0)
	var visuals := Node3D.new()
	actor.add_child(visuals)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	visuals.add_child(mesh)
	t.ok(brain.can_observe(actor), "compound actor exposes its rendered body")
	mesh.hide()
	t.ok(not brain.can_observe(actor), "visible actor origin cannot reveal a hidden child mesh")
	mesh.show()
	visuals.hide()
	t.ok(not brain.can_observe(actor), "hidden visual container suppresses actor observation")
	visuals.show()
	mesh.layers = 2
	t.ok(not brain.can_observe(actor), "actor origin cannot bypass child camera layers")
	mesh.layers = 1
	mesh.position.x = 100.0
	t.ok(not brain.can_observe(actor), "in-frame origin cannot reveal out-of-frame child geometry")
	mesh.position = Vector3.ZERO
	t.ok(brain.can_observe(actor), "body reappearance restores observation")
	var transparent := StandardMaterial3D.new()
	transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	transparent.albedo_color.a = 0.0
	mesh.material_override = transparent
	t.ok(not brain.can_observe(actor), "zero-alpha body is not an observable cue")
	t.ok(not brain._has_visible_geometry(actor, 1), "zero-alpha collision visual is not an occluding wall")
	transparent.albedo_color.a = 0.25
	t.ok(brain.can_observe(actor), "partially transparent body remains observable")
	transparent.albedo_color.a = 0.0
	transparent.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	t.ok(brain.can_observe(actor), "opaque material ignores its unused alpha")
	transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var overlay := StandardMaterial3D.new()
	mesh.material_overlay = overlay
	t.ok(brain.can_observe(actor), "visible overlay preserves an otherwise transparent body cue")
	mesh.material_overlay = null
	transparent.next_pass = overlay
	t.ok(brain.can_observe(actor), "visible additional material pass preserves observation")
	transparent.next_pass = null
	mesh.material_override = null
	mesh.mesh.material = transparent
	t.ok(not brain.can_observe(actor), "mesh surface material also respects zero alpha")
	mesh.set_surface_override_material(0, overlay)
	t.ok(brain.can_observe(actor), "surface override takes precedence over transparent mesh material")
	mesh.set_surface_override_material(0, null)
	context.observation_camera = null
	t.ok(not brain.can_observe(actor), "camera-free simulation respects zero-alpha surface cues")
	context.observation_camera = camera
	transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	t.ok(not brain.can_observe(actor), "zero-alpha depth prepass body is not observable")
	transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	t.ok(brain.can_observe(actor), "unsupported cutoff coverage is not guessed invisible")
	transparent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var tail: Material = transparent
	for index in 4:
		var next := StandardMaterial3D.new()
		next.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		next.albedo_color.a = 0.0
		tail.next_pass = next
		tail = next
	t.ok(brain.can_observe(actor), "long material pass chains have bounded conservative handling")
	transparent.next_pass = null
	mesh.mesh.material = null
	var second := MeshInstance3D.new()
	second.mesh = BoxMesh.new()
	visuals.add_child(second)
	mesh.hide()
	t.ok(brain.can_observe(actor), "another visible body part remains an observable cue")
	second.hide()
	context.observation_camera = null
	t.ok(not brain.can_observe(actor), "camera-free simulation does not observe hidden compound geometry")
	second.show()
	t.ok(brain.can_observe(actor), "camera-free simulation observes visible compound geometry")
	context.observation_camera = camera
	actor.hide()
	t.ok(not brain.can_observe(actor), "hidden actor root suppresses every body part")
	actor.show()
	var marker := Node3D.new()
	root.add_child(marker)
	marker.position = Vector3(0, 1, 0)
	t.ok(brain.can_observe(marker), "authored geometry-free markers retain their observation contract")
	marker.position.x = 100.0
	t.ok(not brain.can_observe(marker), "geometry-free marker still respects the camera frame")
	var deep := Node3D.new()
	root.add_child(deep)
	deep.position = Vector3(0, 1, 0)
	var parent: Node = deep
	for depth in 34:
		var child := Node3D.new()
		parent.add_child(child)
		parent = child
	var hidden_body := MeshInstance3D.new()
	hidden_body.mesh = BoxMesh.new()
	parent.add_child(hidden_body)
	hidden_body.hide()
	t.ok(not brain.can_observe(deep), "exhausted traversal cannot classify an unseen hierarchy as geometry-free")
	root.queue_free()
	await host.get_tree().process_frame
