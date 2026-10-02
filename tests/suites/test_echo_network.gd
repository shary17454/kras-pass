extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("echo network presentation")
	var cfg := MatchConfig.build("symbol_echo", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 106)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	var replica = load("res://src/net/match_replica.gd").new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	packet.phase = MatchPhase.P.PLAYING
	t.ok(replica.accept(packet, 4, "symbol_echo"), "show state survives JSON")
	t.ok(not packet.world.has("sequence") and not packet.world.has("timer"), "answers and future timing stay private")
	for field in packet.world.keys():
		var bad := packet.duplicate(true)
		bad.world.erase(field)
		t.ok(not replica.accept(bad, 4, "symbol_echo"), "reject missing " + field)
	for field in ["stage", "serial", "length", "pad", "step", "flash_left",
		"flash_sequence", "correct_sequence", "wrong_sequence", "finish_sequence"]:
		for value in [null, true, "1", NAN, INF, -2, 1000001]:
			var bad := packet.duplicate(true)
			bad.world[field] = value
			t.ok(not replica.accept(bad, 4, "symbol_echo"), "reject invalid " + field)
	for changes in [{"sequence": [0, 1, 2]}, {"stage": 3}, {"length": 0}, {"length": 10},
		{"pad": 5}, {"pad": 0}, {"step": 0}, {"flash_left": 0.1}, {"progress": [1, 0, 0, 0]},
		{"stage": 1, "progress": [3, 0, 0, 0]}, {"stage": 1, "finished": [0]},
		{"stage": 1, "progress": [3, 0, 0, 0], "finished": [0, 0]},
		{"mistakes": [false, 0, 0, 0]}, {"progress": [0, 0, 0]}, {"finished": [4]}]:
		var bad := packet.duplicate(true)
		bad.world.merge(changes, true)
		t.ok(not replica.accept(bad, 4, "symbol_echo"), "reject inconsistent cue")
	t.equal(replica.target, packet, "invalid data preserves accepted snapshot")
	AudioManager._last_played.erase("tick")
	replica.render(scene, 0.1)
	t.ok(game._sequence.is_empty(), "guest discards generated private answers")
	t.equal(game.sequence_length(), 3, "public length survives without answers")
	t.ok(not AudioManager._last_played.has("tick"), "initial state stays silent")
	game._flash(2)
	game._show_index = 1
	packet = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	packet.phase = MatchPhase.P.PLAYING
	AudioManager._last_played.erase("tick")
	t.ok(replica.accept(packet, 4, "symbol_echo"), "accept visible host cue")
	replica.render(scene, 0.1)
	t.equal(game.visible_symbol(), 2, "guest sees current symbol")
	t.equal(game.visible_step(), 0, "guest sees current step")
	if AudioManager.enabled:
		t.ok(AudioManager._last_played.has("tick"), "fresh cue plays audio")
	AudioManager._last_played.erase("tick")
	var scores := Array(scene.ctx.scores)
	var timer: float = game._timer
	for repeat in 10:
		replica.render(scene, 1.0)
	t.ok(not AudioManager._last_played.has("tick"), "duplicate cue remains silent")
	t.equal(Array(scene.ctx.scores), scores, "presentation cannot score")
	t.near(game._timer, timer, 0.00001, "presentation cannot advance rules")
	packet.world.flash_sequence += 1
	packet.world.step = 1
	t.ok(replica.accept(packet, 4, "symbol_echo"), "accept repeated symbol at next step")
	replica.render(scene, 0.1)
	t.equal(game.visible_step(), 1, "identical symbol retains distinct step")
	packet.world.stage = 1
	packet.world.pad = -1
	packet.world.step = -1
	packet.world.flash_left = 0
	packet.world.progress = [3, 1, 0, 0]
	packet.world.finished = [0]
	packet.world.mistakes = [0, 0, 1, 0]
	t.ok(replica.accept(packet, 4, "symbol_echo"), "accept host progress")
	replica.render(scene, 0.1)
	t.equal(game.visible_symbol(), -1, "input hides cue")
	t.equal(game.progress_of(1), 1, "guest sees partial progress")
	t.equal(game.mistakes_of(2), 1, "guest sees mistakes")
	t.equal(game.expected_pad(1), -1, "guest cannot query next private answer")
	packet.world.correct_sequence += 1
	AudioManager._last_played.erase("correct")
	t.ok(replica.accept(packet, 4, "symbol_echo"), "accept reconnect state")
	replica._event_received_at = replica.received_at - 1501
	replica.render(scene, 0.1)
	t.ok(not AudioManager._last_played.has("correct"), "reconnect skips historical audio")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
