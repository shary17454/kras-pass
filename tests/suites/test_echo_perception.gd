extends RefCounted

class CueController extends MiniGameController:
	var symbol := 2
	var step := 0
	var serial := 1
	var progress := 0
	var mistakes := 0
	var occupied := -1
	var secret := 4
	var secret_queries := 0
	func visible_symbol() -> int: return symbol
	func visible_step() -> int: return step
	func sequence_serial() -> int: return serial
	func is_showing() -> bool: return false
	func accepts_sequence_input() -> bool: return true
	func sequence_length() -> int: return 3
	func progress_of(_slot: int) -> int: return progress
	func mistakes_of(_slot: int) -> int: return mistakes
	func current_pad(_slot: int) -> int: return occupied
	func pad_position(_index: int) -> Vector3: return Vector3(8, 0, 0)
	func expected_pad(_slot: int) -> int:
		secret_queries += 1
		return secret


func run(t: TestHarness, host: Node) -> void:
	t.suite("echo observed memory")
	var cfg := MatchConfig.build("symbol_echo", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 108)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var cue := CueController.new()
	var brain = load("res://src/ai/brains/echo_brain.gd").new()
	brain.configure(0, scene.ctx, 3, 91)
	brain.controller = cue
	brain.accuracy = 1.0
	brain.reaction_time = 0.5
	brain._sync_sequence()
	brain._observe_cue()
	t.equal(brain._recall(0), -1, "observed symbol is unavailable before reaction delay")
	brain._time += 0.5
	t.equal(brain._recall(0), 2, "memory recalls the observed symbol, not the secret answer")
	cue.symbol = 4
	brain._observe_cue()
	t.equal(brain._recall(0), 2, "repeated sampling cannot reroll the same observed step")
	brain.decide(0.0)
	t.equal(brain._attempt, 2, "decision uses observed memory")
	t.equal(cue.secret_queries, 0, "decision never queries the secret answer")
	brain._attempt = 4
	brain._attempt_step = 2
	brain._recall_noise[2] = 4
	brain._recall_noise[0] = 1
	cue.mistakes = 1
	brain._note_misses()
	t.ok(brain._ruled_out[2].has(4), "miss rules out the attempted step, not reset progress zero")
	t.ok(not brain._ruled_out.has(0), "later miss does not corrupt first-step knowledge")
	t.equal(brain._recall_noise[0], 1, "earlier correct belief survives")
	t.ok(brain._recall(2) != 4, "next guess excludes disproven symbol")
	cue.serial += 1
	cue.symbol = -1
	brain._sync_sequence()
	t.equal(brain._observations.size(), 0, "new sequence clears old observations")
	t.equal(brain._ruled_out.size(), 0, "new sequence clears exclusions")
	var other = load("res://src/ai/brains/echo_brain.gd").new()
	other.configure(0, scene.ctx, 3, 123)
	other.controller = cue
	brain.configure(0, scene.ctx, 3, 123)
	brain.on_round_start()
	brain._sync_sequence()
	other._sync_sequence()
	brain._observe_cue()
	other._observe_cue()
	cue.secret = 0
	var first_guess: int = brain._recall(1)
	cue.secret = 4
	t.equal(other._recall(1), first_guess, "unseen-symbol guesses are independent of hidden answers")
	t.ok(first_guess >= 0 and first_guess < 5, "unseen-symbol guess is a legal pad")
	t.equal(cue.secret_queries, 0, "unseen-symbol recovery never reads hidden state")
	brain._recall_noise[0] = 2
	cue.occupied = 2
	scene.ctx.fighter(0).global_position = Vector3(4, 1, 0)
	brain.decide(0.0)
	t.ok(brain.move.x < 0, "repeated pad requires stepping away before another entry")
	var game = scene.controller
	game.on_round_start()
	t.equal(game.visible_symbol(), -1, "pre-display wait exposes no symbol")
	game.tick(0.6)
	t.equal(game.visible_step(), 0, "first illuminated cue exposes its visible index")
	t.equal(game.visible_symbol(), game._sequence[0], "visible API matches illuminated pad")
	game._stage = game.Stage.INPUT
	t.equal(game.visible_symbol(), -1, "input stage hides the sequence")
	game._stage = game.Stage.RESOLVE
	t.equal(game.visible_symbol(), -1, "resolution cannot reveal the answer")
	cue.free()
	scene.phase = MatchPhase.P.PLAYING
	scene.ctx.phase = scene.phase
	scene._begin_play()
	game._sequence.assign([0, 0, 1])
	for opponent in scene._brains:
		opponent.accuracy = 1.0
		opponent.reaction_time = 0.1
		opponent.mistake_chance = 0.0
		opponent.input_noise = 0.0
		opponent.decision_interval = 0.05
	scene.set_physics_process(true)
	var serial: int = game.sequence_serial()
	var completed := false
	var last_progress := ""
	for frame in 14 * 60:
		await host.get_tree().physics_frame
		if game.accepts_sequence_input():
			last_progress = "progress=%s mistakes=%s positions=%s" % [game._progress, game._mistakes, scene.ctx.fighters.map(func(f): return f.global_position)]
		completed = not game._finished.is_empty()
		if completed or game.sequence_serial() != serial:
			break
	t.ok(completed, "real AI movement completes an observed sequence with a repeated symbol: " + last_progress)
	for opponent in scene._brains:
		t.equal(opponent._observations.size(), 3, "active AI observed all three displayed steps")
		for step in 3:
			t.equal(int(opponent._observations.get(step, {}).get("pad", -1)), [0, 0, 1][step], "accurate AI remembers actual displayed symbols")
	scene.set_physics_process(false)
	var fighter: Fighter = scene.ctx.fighter(0)
	for initial in [Vector3(0, 0, 0.999471), Vector3(0, 0, 1.000687), Vector3.ZERO]:
		for direction in [Vector3(0.000001, 0, -1), Vector3(-0.000001, 0, -1)]:
			fighter.facing = initial
			fighter._integrate_walk(direction, 1.0 / 60.0)
			t.near(fighter.facing.length(), 1.0, 0.00001, "near-opposite walk turn preserves normalized facing")
			t.near(fighter.facing.y, 0.0, 0.00001, "walk turn stays on the horizontal plane")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
