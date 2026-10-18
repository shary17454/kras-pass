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
	for first in 4:
		for second in 4:
			if first == second:
				continue
			game.on_round_start()
			for slot in 4:
				scene.ctx.alive[slot] = true
				scene.ctx.set_score(slot, 0)
				InputRouter.frame(slot).bits = 0
				InputRouter.frame(slot).prev_bits = 0
			game._fire_signal()
			InputRouter.frame(first).bits = InputFrame.Btn.ATTACK
			InputRouter.frame(second).bits = InputFrame.Btn.ATTACK
			game._watch_draws()
			var later := (second + 1) % 4
			while later == first or later == second:
				later = (later + 1) % 4
			InputRouter.frame(first).bits = 0
			InputRouter.frame(second).bits = 0
			InputRouter.frame(later).bits = InputFrame.Btn.ATTACK
			game._watch_draws()
			game._resolve()
			t.equal(scene.ctx.scores[first], 3, "same-tick first participant shares first place")
			t.equal(scene.ctx.scores[second], 3, "same-tick second participant shares first place")
			t.equal(scene.ctx.scores[later], 1, "later response ranks after both tied participants")
			t.ok(not game.is_round_over(), "ordinary reaction game continues after a scored signal")
	t.test("tournament decider ends on the first scored signal, without slot bias")
	cfg.rules["party_tiebreak"] = true
	for first in 4:
		game.on_round_start()
		scene.ctx.early_finish = false
		for slot in 4:
			scene.ctx.set_score(slot, 0)
			InputRouter.frame(slot).bits = 0
			InputRouter.frame(slot).prev_bits = 0
		game._fire_signal()
		InputRouter.frame(first).bits = InputFrame.Btn.ATTACK
		game._watch_draws()
		game._resolve()
		t.ok(game.is_round_over(), "first valid response ends the decider for slot %d" % first)
		var result := MatchResult.make("quick_draw", cfg.arena_id, scene.ctx.scores)
		t.equal(result.winners(), [first], "decider winner follows the response, not roster order")
	game.on_round_start()
	scene.ctx.early_finish = false
	for slot in 4:
		scene.ctx.set_score(slot, 0)
		InputRouter.frame(slot).bits = 0
		InputRouter.frame(slot).prev_bits = 0
	game._fire_signal()
	for slot in [1, 3]:
		InputRouter.frame(slot).bits = InputFrame.Btn.ATTACK
	game._watch_draws()
	game._resolve()
	t.ok(game.is_round_over(), "simultaneous first responses finish the scored signal")
	var tied := MatchResult.make("quick_draw", cfg.arena_id, scene.ctx.scores)
	t.equal(tied.winners(), [1, 3], "simultaneous responders remain tied for the next decider")
	game.on_round_start()
	scene.ctx.early_finish = false
	for slot in 4:
		InputRouter.frame(slot).bits = InputFrame.Btn.ATTACK
		InputRouter.frame(slot).prev_bits = 0
	game._watch_false_starts()
	game._fire_signal()
	game._watch_draws()
	game._resolve()
	t.ok(not game.is_round_over(), "false starts do not award a decider victory")
	game.on_round_start()
	for slot in 4:
		InputRouter.frame(slot).bits = 0
		InputRouter.frame(slot).prev_bits = 0
	game._fire_signal()
	game._resolve()
	t.ok(not game.is_round_over(), "unanswered signal waits within the existing timeout")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
	await _tournament_completion(t, host, cfg.players)


func _tournament_completion(t: TestHarness, host: Node, roster: Array[PlayerConfig]) -> void:
	t.test("first-response result completes the remapped tournament through the match lifecycle")
	var session := TournamentSession.new()
	session.setup(roster, ["ring_rumble"] as Array[String], 209)
	session.record(MatchResult.make("ring_rumble", "vortex_ring", [0, 5, 0, 5] as Array[int]))
	var cfg := session.next_config()
	t.equal(cfg.players.size(), 2, "only the original tied leaders enter the decider")
	t.ok(bool(cfg.rule("party_tiebreak", false)), "decider carries its first-response rule")
	var outcomes: Array[MatchResult] = []
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(result: MatchResult):
		outcomes.append(result)
		session.record(result)})
	scene.set_physics_process(false)
	for next in [MatchPhase.P.INSTRUCTIONS, MatchPhase.P.COUNTDOWN, MatchPhase.P.PLAYING]:
		scene._set_phase(next)
	for slot in cfg.players.size():
		InputRouter.frame(slot).bits = 0
		InputRouter.frame(slot).prev_bits = 0
	var game = scene.controller
	game._fire_signal()
	InputRouter.frame(1).bits = InputFrame.Btn.ATTACK
	game._watch_draws()
	game._resolve()
	t.ok(scene.ctx.time_left > 0.0, "decider finishes before the visible clock expires")
	scene._evaluate_end(1.0 / 60.0)
	t.equal(scene.phase, MatchPhase.P.FINISH, "controller completion enters the real finish phase")
	scene._physics_process(scene._phase_timer + 0.01)
	t.equal(scene.phase, MatchPhase.P.DONE, "finish animation advances through results to done")
	t.equal(outcomes.size(), 1, "match delivers exactly one aggregate result")
	if outcomes.size() == 1:
		t.ok(outcomes[0].finished_naturally, "first response remains eligible for tournament completion")
		t.equal(outcomes[0].winners(), [1], "result uses the remapped contender slot")
	t.ok(session.is_complete(), "real match result completes the tournament")
	t.equal(session.champion(), 3, "champion maps back to the original roster")
	t.equal(session.ranking()[0], 3, "podium ranks the same original winner first")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
