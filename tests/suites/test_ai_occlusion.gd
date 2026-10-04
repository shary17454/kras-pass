extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("AI world occlusion")
	var root := Node3D.new()
	host.add_child(root)
	root.position.y = 1000.0
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 1, 10)
	camera.look_at(root.global_position + Vector3.UP, Vector3.UP)
	camera.set_perspective(90, 0.1, 50)
	var context := MatchContext.new()
	context.config = MatchConfig.build("ring_rumble", ["fanoos"], 0, 1, 119)
	context.observation_camera = camera
	var brain := AIBrain.new()
	brain.configure(0, context, 3, 119)
	var target := Node3D.new()
	root.add_child(target)
	target.position = Vector3(0, 1, 0)
	t.ok(brain.can_observe(target), "unobstructed in-frame target is visible")
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	root.add_child(wall)
	wall.position = Vector3(0, 1, 5)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(4, 4, 1)
	mesh.mesh = box
	wall.add_child(mesh)
	var shape := CollisionShape3D.new()
	var collision := BoxShape3D.new()
	collision.size = box.size
	shape.shape = collision
	wall.add_child(shape)
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	t.ok(not brain.can_observe(target), "opaque world wall blocks an in-frame target")
	var partial := MeshInstance3D.new()
	var partial_box := BoxMesh.new()
	partial_box.size = Vector3(10, 1, 1)
	partial.mesh = partial_box
	root.add_child(partial)
	partial.position = target.position
	t.ok(brain.can_observe(partial), "mesh protruding beyond wall remains partly visible")
	partial_box.size = Vector3.ONE
	t.ok(not brain.can_observe(partial), "mesh entirely behind wall remains hidden")
	partial.queue_free()
	mesh.hide()
	t.ok(brain.can_observe(target), "hidden mesh with active collider does not hide a target")
	mesh.show()
	mesh.layers = 2
	camera.cull_mask = 1
	t.ok(brain.can_observe(target), "camera-culled wall does not hide a target")
	mesh.layers = 1
	wall.collision_layer = 2
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	t.ok(brain.can_observe(target), "player collision layer is not an opaque world obstacle")
	wall.collision_layer = 1
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	t.ok(not brain.can_observe(target), "restoring world layer restores occlusion")
	t.ok(brain.can_observe(mesh), "target's own world body is not its occluder")
	camera.global_position = wall.global_position
	t.ok(not brain.can_observe(target), "camera inside opaque wall fails closed")
	camera.position = Vector3(0, 1, 10)
	wall.position = Vector3(0, -1, 0)
	camera.position = Vector3(0, 5, 10)
	camera.look_at(target.global_position, Vector3.UP)
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	t.ok(brain.can_observe(target), "ray ending on floor surface is not intervening occlusion")
	target.position.y = 0.0
	t.ok(not brain.can_observe(target), "buried target is not mistaken for surface contact")
	var exposed := MeshInstance3D.new()
	var exposed_box := BoxMesh.new()
	exposed_box.size = Vector3(0.5, 3, 0.5)
	exposed.mesh = exposed_box
	target.add_child(exposed)
	t.ok(brain.can_observe(target), "child mesh protruding above floor is visible even with buried actor origin")
	exposed.hide()
	t.ok(not brain.can_observe(target), "hidden child geometry cannot reveal buried actor origin")
	exposed.queue_free()
	mesh.reparent(root, true)
	wall.set_meta("observation_mesh", wall.get_path_to(mesh))
	t.ok(not brain.can_observe(target), "sibling terrain mesh remains associated with its collider")
	mesh.hide()
	t.ok(brain.can_observe(target), "hidden sibling terrain is not a visual occluder")
	mesh.show()
	target.position.y = 1.0
	wall.queue_free()
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	t.ok(brain.can_observe(target), "removed wall no longer blocks the target")
	root.queue_free()
	await host.get_tree().process_frame
