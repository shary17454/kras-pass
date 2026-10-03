extends RefCounted

func run(t: TestHarness, host: Node) -> void:
	t.suite("colossus respawns do not overlap active bodies")
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": MatchConfig.build("boss_colossus", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 9614), "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	scene.arena.current_radius = 5.0
	scene.arena._crater_floor.set_radius(5.0)
	for fighter in scene.ctx.fighters:
		fighter.alive = false
		fighter.visible = false
		fighter.global_position = Vector3(0, -500, 0)
	var points: Array[Vector3] = []
	for slot in 4:
		var point: Vector3 = scene.controller.safe_respawn_position(slot)
		t.ok(scene.arena.is_inside(point, 1.0), "respawn remains on actual ground")
		for previous in points:
			t.ok(Vector2(point.x - previous.x, point.z - previous.z).length() >= 0.94, "sequential returning players have capsule clearance")
		points.append(point)
		scene.ctx.fighter(slot).respawn_at(point)
	var occupied: Vector3 = scene.ctx.fighter(0).global_position
	t.ok(scene.controller.safe_respawn_position(1).distance_to(occupied) >= 0.94, "occupied center cannot be reused")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
