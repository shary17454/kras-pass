extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("race round reset")
	var cfg := MatchConfig.build("kart_sprint", ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 117)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	for rider in scene.ctx.fighters: rider.set_physics_process(false)
	var game: Node = scene.controller
	var pad: Dictionary = game._boost_pads[0]
	var rider: Fighter = scene.ctx.fighter(0)
	rider.global_position = pad.pos + Vector3.UP
	game._check_boost(0, rider, 1.0 / 60.0)
	t.ok(pad.cooldown.has(0), "actual pad contact starts per-player recharge")
	t.near(pad.cooldown[0], 2.0, 0.001, "actual recharge retains its authored duration")
	t.ok(not game.boost_pad_positions(0).has(pad.pos), "recharging pad is not advertised as available")
	game.on_round_start()
	t.ok(pad.cooldown.is_empty(), "new round cannot inherit old pad cooldown")
	t.ok(game.boost_pad_positions(0).has(pad.pos), "new round restores pad availability")
	game._check_boost(0, rider, 1.0 / 60.0)
	t.ok(pad.cooldown.has(0), "first pad contact of next round is accepted")
	game.on_round_start()
	var original_context: int = cfg.context
	cfg.context = MatchConfig.Context.ONLINE
	cfg.players[0].is_human = true
	cfg.players[0].peer_id = 1
	cfg.players[1].peer_id = 2
	t.equal(cfg.human_slots(), [0], "local device roster excludes the remote human")
	t.equal(cfg.human_competitor_slots(), [0, 1], "race roster includes both local and remote humans")
	for slot in 4: scene.ctx.fighter(slot).global_position = Vector3(100 + slot * 10, 1, 100)
	_finish_checkpoints(game, scene.ctx.fighter(0))
	t.ok(game.finish_times[0] != game.UNFINISHED, "ordered checkpoint ticks finish the host's three laps")
	t.equal(game.lap[0], 3, "host finish retains the requested three laps")
	t.ok(not game.is_round_over(), "host finish cannot end a race while remote human is unfinished")
	_finish_checkpoints(game, scene.ctx.fighter(1))
	t.ok(game.finish_times[1] != game.UNFINISHED, "ordered checkpoint ticks finish the remote human")
	t.ok(game.is_round_over(), "all human competitors finishing can end the race")
	t.equal(game.finish_times[2], game.UNFINISHED, "unfinished bot does not block human completion")
	cfg.context = original_context
	t.equal(cfg.human_competitor_slots(), [0], "offline rules ignore stale remote peer metadata")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame


func _finish_checkpoints(game: Node, rider: Fighter) -> void:
	# Rule-level fixture only, not physical-race or network qualification.
	for step in game.laps() * game._checkpoints.size() + 1:
		rider.global_position = game.next_checkpoint(rider.slot)
		game.tick(1.0 / 60.0)
