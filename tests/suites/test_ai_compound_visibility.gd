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
