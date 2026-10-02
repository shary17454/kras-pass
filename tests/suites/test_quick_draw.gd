extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("quick draw lifecycle")
	var cfg := MatchConfig.build("quick_draw", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 102)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	game._fire_signal()
	game._signal_age = 1.0
	game._locked[1] = true
	game._order.append(0)
	game._round_no = 10
	game.on_round_start()
	t.equal(game._stage, game.Stage.WAIT, "new round waits for a fresh signal")
	t.equal(game._round_no, 1, "new round resets prompt counter")
	t.equal(game._order.size(), 0, "new round clears response order")
	t.equal(game._locked.size(), 0, "new round clears false-start locks")
	t.near(game.signal_age(), 0.0, 0.00001, "new round clears signal age")
	t.ok(game._timer >= 1.6 and game._timer <= 4.5, "new round restores full random wait")
	game._begin_wait()
	for i in 4:
		InputRouter.frame(i).bits = 0
		InputRouter.frame(i).prev_bits = 0
	scene.ctx.alive[3] = false
	scene.ctx.set_score(3, 5)
	InputRouter.frame(3).bits = InputFrame.Btn.ATTACK
	game._watch_false_starts()
	t.ok(not game.is_locked(3), "spectator cannot false start")
	t.equal(scene.ctx.scores[3], 5, "spectator score cannot be penalized")
	game._locked.clear()
	game._fire_signal()
	game._watch_draws()
	t.ok(not game._order.has(3), "spectator cannot enter reaction ranking")
	game._resolve()
	t.equal(scene.ctx.scores[3], 5, "spectator cannot win reaction points")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
