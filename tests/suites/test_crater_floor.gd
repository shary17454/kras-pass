extends RefCounted

const Floor = preload("res://src/arenas/crater_floor.gd")

func run(t: TestHarness, host: Node) -> void:
	t.suite("crater physical floor")
	var floor_node = Floor.new()
	host.add_child(floor_node)
	floor_node.build(16.0, 1.0, StandardMaterial3D.new())
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	t.ok(_ground(floor_node, Vector3(4, 0, 0)), "uncut floor has physical ground")
	floor_node.open_hole(Vector3(4, 0, 0), 3.0)
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	for point in [Vector3(4, 0, 0), Vector3(5, 0, 0), Vector3(4, 0, 2)]:
		t.ok(not _ground(floor_node, point), "crater removes actual collision")
		t.ok(not floor_node.has_ground(point), "ground query excludes crater")
	for point in [Vector3(-4, 0, 0), Vector3(8, 0, 0), Vector3(0, 0, 8)]:
		t.ok(_ground(floor_node, point), "floor outside crater remains collidable")
	t.ok(not floor_node.path_clear(Vector3(-4, 0, 0), Vector3(8, 0, 0)), "safe endpoints cannot authorize crossing a hole")
	t.ok(floor_node.path_clear(Vector3(-4, 0, 0), Vector3(-8, 0, 0)), "clear segment remains traversable")
	t.ok(not floor_node.path_clear(Vector3(4, 0, 0), Vector3(-4, 0, 0)), "path with carved start is rejected")
	t.ok(not floor_node.path_clear(Vector3(-4, 0, 0), Vector3(-18, 0, 0)), "path cannot leave arena rim")
	floor_node.open_hole(Vector3(6, 0, 0), 3.0)
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	t.ok(not _ground(floor_node, Vector3(8, 0, 0)), "overlapping cut removes new ground")
	t.ok(_ground(floor_node, Vector3(-4, 0, 0)), "overlapping cuts preserve other ground")
	floor_node.reset()
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	t.ok(_ground(floor_node, Vector3(4, 0, 0)), "round reset restores crater collision")
	t.empty(floor_node.holes, "reset removes old holes")
	floor_node.set_radius(8.07)
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	t.ok(_ground(floor_node, Vector3(7.5, 0, 0)), "shrunken inner floor remains solid")
	t.ok(not _ground(floor_node, Vector3(8.2, 0, 0)), "shrink removes outer collision")
	floor_node.open_hole(Vector3.ZERO, 20.0)
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	t.ok(not _ground(floor_node, Vector3.ZERO), "fully removed floor has no ground")
	floor_node.reset()
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	t.ok(_ground(floor_node, Vector3.ZERO), "fully removed floor can be restored")
	var body := CharacterBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 1
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.4
	shape.shape = sphere
	body.add_child(shape)
	host.add_child(body)
	body.global_position = Vector3(4, 2, 0)
	for frame in 60:
		await host.get_tree().physics_frame
		body.velocity.y -= 20.0 / 60.0
		body.move_and_slide()
	t.ok(body.is_on_floor() and body.global_position.y > 0, "moving physics body stands on restored floor")
	floor_node.open_hole(Vector3(4, 0, 0), 3.0)
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	for frame in 90:
		await host.get_tree().physics_frame
		body.velocity.y -= 20.0 / 60.0
		body.move_and_slide()
	t.ok(body.global_position.y < -14.0, "gravity carries body through hole below fall threshold")
	body.queue_free()
	floor_node.use_presentation_only()
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	t.ok(floor_node._body == null and floor_node._shape == null, "presentation floor relinquishes physics ownership")
	t.equal(floor_node._mesh.get_parent(), floor_node, "presentation mesh survives body retirement")
	t.ok(not _ground(floor_node, Vector3.ZERO), "presentation floor creates no physical ground")
	var snapshot: Array = [{"point": Vector2(2, 0), "radius": 1.5}]
	floor_node.apply_snapshot(7.07, snapshot)
	t.near(floor_node.radius, 7.0, 0.001, "presentation uses authored radius quantization")
	t.ok(not floor_node.has_ground(Vector3(2, 0, 0)), "presentation ground query follows host crater")
	t.ok(floor_node.has_ground(Vector3(-3, 0, 0)), "presentation retains uncut ground queries")
	var mesh: Mesh = floor_node._mesh.mesh
	floor_node.apply_snapshot(7.07, snapshot)
	t.equal(floor_node._mesh.mesh, mesh, "identical snapshot does not rebuild geometry")
	snapshot[0].radius = 4.0
	t.near(floor_node.holes[0].radius, 1.5, 0.001, "snapshot holes are detached from caller mutations")
	floor_node.apply_snapshot(8.0, [])
	t.empty(floor_node.holes, "new round snapshot removes old crater geometry")
	t.ok(floor_node.has_ground(Vector3(2, 0, 0)), "new round restores visual ground query")
	t.ok(floor_node._mesh.mesh != mesh, "changed snapshot rebuilds visual geometry")
	t.ok(not _ground(floor_node, Vector3.ZERO), "snapshot rebuilding never recreates collider")
	floor_node.use_presentation_only()
	t.ok(floor_node._body == null, "presentation conversion is idempotent")
	floor_node.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": MatchConfig.build("boss_colossus", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 345), "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	for fighter in scene.ctx.fighters: fighter.set_physics_process(false)
	var arena: Arena = scene.arena
	var game: Node = scene.controller
	game._open_crater(Vector3.ZERO, 40.0)
	t.ok(not arena.is_inside(Vector3.ZERO), "real boss opens physical arena crater")
	var spawn: Vector3 = game.safe_respawn_position(0)
	t.ok(arena.is_inside(spawn, 1.0), "exhausted arena restores safe respawn ground")
	t.empty(game._craters, "emergency recovery also removes crater visuals")
	game._open_crater(Vector3(4, 0, 0), 4.0)
	scene._start_next_round()
	t.ok(arena.is_inside(Vector3(4, 0, 0)), "real next round removes previous crater")
	game._open_crater(Vector3.ZERO, 4.0)
	var rim := Vector3(3.6, 0, 0)
	var retreat := arena.retreat_point(rim)
	t.ok(arena.is_inside(retreat, 1.0), "retreat never targets carved center")
	t.ok(retreat.x > rim.x, "retreat moves outward from center crater")
	for step in 8:
		t.ok(arena.is_inside(rim.lerp(retreat, float(step + 1) / 8), 0.42), "retreat path preserves body clearance")
	game.cleanup()
	t.ok(arena._crater_floor == null, "cleanup releases carved floor ownership")
	t.ok(arena._floor_mesh.visible, "cleanup restores original floor appearance")
	t.equal(arena._floor_mesh.get_parent().collision_layer, 1, "cleanup restores original floor collision")
	t.near(arena.retreat_point(rim).x, 0.0, 0.001, "ordinary disc retreat behavior remains unchanged after cleanup")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame

func _ground(node: Node3D, point: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 5, point + Vector3.DOWN * 3, 1)
	return not node.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
