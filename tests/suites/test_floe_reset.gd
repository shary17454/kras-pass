extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("moving floe lifecycle")
	var cfg := MatchConfig.build("drift_floes", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 117)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	for floe in game._floes:
		floe.body.sync_to_physics = false
	game.on_round_start()
	game.tick(0.0)
	var initial: Array = []
	for floe in game._floes:
		initial.append(floe.body.global_position)
	for round_index in 3:
		game.tick(9.0)
		game.on_sudden_death()
		game.tick(3.0)
		game.on_round_start()
		t.equal(game._time, 0.0, "round resets motion clock")
		for index in 3:
			var floe: Dictionary = game._floes[index]
			t.ok(is_equal_approx(float(floe.speed), 0.34 + 0.09 * index), "round restores authored movement speed")
			t.ok(floe.body.global_position.is_equal_approx(initial[index]), "round restores platform before countdown")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
