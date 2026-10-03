extends RefCounted

func run(t: TestHarness, host: Node) -> void:
	t.suite("shrinking arena ejection")
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": MatchConfig.build("boss_colossus", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 9614), "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var fighter: Fighter = scene.ctx.fighter(0)
	scene.arena.current_radius = scene.arena.def.radius - 1.0
	fighter.global_position = scene.arena.global_position + Vector3(50, 2, 0)
	fighter._impulse = Vector3.ZERO
	scene._check_out_of_bounds()
	t.near(fighter._impulse.length(), 4.0, 0.001, "first exit receives one ejection")
	for tick in 120:
		scene._check_out_of_bounds()
	t.near(fighter._impulse.length(), 4.0, 0.001, "remaining outside cannot accumulate impulses")
	fighter.global_position = scene.arena.global_position + Vector3(0, 2, 0)
	scene._check_out_of_bounds()
	fighter._impulse = Vector3.ZERO
	fighter.global_position = scene.arena.global_position + Vector3(50, 2, 0)
	scene._check_out_of_bounds()
	t.near(fighter._impulse.length(), 4.0, 0.001, "returning to ground permits a new exit cue")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
