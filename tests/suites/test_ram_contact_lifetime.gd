extends RefCounted

func run(t: TestHarness, host: Node) -> void:
	t.suite("body contacts expire after their physics tick")
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": MatchConfig.build("boss_colossus", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 9614), "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var a: Fighter = scene.ctx.fighter(0)
	var b: Fighter = scene.ctx.fighter(1)
	Fighter.clear_impact_state()
	a._pre_vel = Vector3(10, 0, 0)
	b._pre_vel = Vector3.ZERO
	a._invuln = 0.0
	b._invuln = 0.0
	Fighter._contacts["0:1"] = {"a": a, "b": b, "into": Vector3.RIGHT}
	Fighter.resolve_impacts(1.0 / 60.0)
	t.ok(b._impulse.length() > 0.0, "fresh contact still delivers an impact")
	var first: Vector3 = b._impulse
	b.global_position = Vector3(100, 2, 0)
	a._invuln = 0.0
	b._invuln = 0.0
	Fighter.resolve_impacts(1.0)
	t.near(b._impulse.distance_to(first), 0.0, 0.001, "old separated pair cannot deliver another impact")
	t.ok(Fighter._contacts.is_empty(), "per-tick contact queue is drained")
	Fighter.clear_impact_state()
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
