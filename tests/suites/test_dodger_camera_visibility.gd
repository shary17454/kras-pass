extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("dodger actual arm visibility")
	var arena := Arena.new()
	host.add_child(arena)
	arena.position.y = 1000.0
	var arm := ArenaHazards.Sweeper.new()
	arena.add_child(arm)
	arm.build(Color.WHITE, 8.0, 0.85)
	var camera := Camera3D.new()
	arena.add_child(camera)
	camera.position = Vector3(4, 4, 12)
	camera.set_perspective(90, 0.1, 50)
	var look := arena.global_position + Vector3(4, 0.85, 0)
	camera.look_at(look, Vector3.UP)
	var ctx := MatchContext.new()
	ctx.arena = arena
	ctx.observation_camera = camera
	ctx.config = MatchConfig.build("sweeper_storm", ["fanoos"], 0, 1, 119)
	var brain = load("res://src/ai/brains/dodger_brain.gd").new()
	brain.configure(0, ctx, 3, 119)
	brain.reaction_time = 0.5
	brain.prediction = 0.0
	brain.edge_awareness = 1.0
	var target := arena.global_position + Vector3.RIGHT.rotated(Vector3.UP, 0.5) * 3.0
	brain._record_history()
	brain._time = 0.1
	arm.rotation.y = 0.1
	brain._record_history()
	brain._time = 0.6
	t.ok(brain.can_observe(arm._arm_mesh), "fixture arm is in the actual camera frame")
	t.ok(not brain._incoming_arm(arena, target).is_empty(), "visible delayed angular samples permit dodge prediction")
	camera.look_at(arena.global_position + Vector3(4, 4, 30), Vector3.UP)
	t.ok(not brain.can_observe(arm._arm_mesh), "camera reversal actually hides the arm")
	t.ok(brain._incoming_arm(arena, target).is_empty(), "off-screen arm cannot use its old trajectory")
	brain._time = 0.7
	brain._record_history()
	t.empty(brain._history_sweepers.back(), "off-screen geometry cannot enter angular history")
	t.empty(brain._arm_seen_since, "off-screen blades lose reaction credit")
	camera.look_at(look, Vector3.UP)
	brain._time = 0.8
	arm.rotation.y = 0.2
	brain._record_history()
	t.ok(brain._incoming_arm(arena, target).is_empty(), "reappearance cannot reuse pre-gap reaction credit")
	brain._time = 0.9
	arm.rotation.y = 0.3
	brain._record_history()
	brain._time = 1.4
	target = arena.global_position + Vector3.RIGHT.rotated(Vector3.UP, 0.7) * 3.0
	t.ok(not brain._incoming_arm(arena, target).is_empty(), "fresh visible motion becomes actionable after a new delay")
	var old_material := arm._arm_mesh.material_override
	var invisible := StandardMaterial3D.new()
	invisible.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	invisible.albedo_color.a = 0.0
	arm._arm_mesh.material_override = invisible
	t.ok(brain.can_observe(arm), "visible hub alone still reveals the compound hazard")
	t.ok(not brain.can_observe(arm._arm_mesh), "zero-alpha arm is not a rendered trajectory cue")
	t.ok(brain._incoming_arm(arena, target).is_empty(), "visible hub cannot reveal the invisible blade trajectory")
	brain._time = 1.5
	brain._record_history()
	t.empty(brain._history_sweepers.back(), "invisible blade cannot enter angular history")
	arm._arm_mesh.material_override = old_material
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	arena.add_child(wall)
	wall.position = Vector3(4, 1, 6)
	var mesh := MeshFactory.box(Vector3(24, 12, 1), Color.WHITE)
	wall.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(24, 12, 1)
	shape.shape = box
	wall.add_child(shape)
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	t.ok(not brain.can_observe(arm._arm_mesh), "real world collider and opaque mesh hide the blade")
	t.ok(brain._incoming_arm(arena, target).is_empty(), "occluded blade cannot direct a dodge")
	brain._time = 1.6
	brain._record_history()
	t.empty(brain._history_sweepers.back(), "world-occluded blade cannot enter angular history")
	t.empty(brain._arm_seen_since, "occluded blades lose reaction credit")
	wall.queue_free()
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	brain._time = 1.7
	brain._record_history()
	t.equal(brain._arm_seen_since.size(), 1, "unblocked live blade regains a bounded observation entry")
	arm.queue_free()
	await host.get_tree().process_frame
	brain._time = 2.0
	brain._record_history()
	t.empty(brain._arm_seen_since, "removed blades do not accumulate observation IDs")
	arena.queue_free()
	await host.get_tree().process_frame
