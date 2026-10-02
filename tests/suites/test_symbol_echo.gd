extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("symbol echo lifecycle")
	var cfg := MatchConfig.build("symbol_echo", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 107)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	var start_length := int(Balance.num("tuning", "reaction.sequence_start_length", 3))
	game._length = 9
	game._new_sequence()
	game._stage = game.Stage.INPUT
	game._timer = 30.0
	game._progress.fill(2)
	game._last_pad.fill(1)
	game._mistakes.fill(4)
	game._finished.append(0)
	game._show_index = 6
	var serial: int = game.sequence_serial()
	game._flash(0)
	game.on_round_start()
	t.equal(game._length, start_length, "restart restores initial sequence length")
	t.equal(game._sequence.size(), start_length, "restart deals the initial number of symbols")
	t.equal(game._stage, game.Stage.SHOW, "restart begins with observation")
	t.equal(game._show_index, 0, "restart clears display cursor")
	t.equal(game._finished.size(), 0, "restart clears finish order")
	t.ok(game.sequence_serial() > serial, "restart invalidates prior AI memory")
	t.near(game._timer, 0.6, 0.00001, "restart restores pre-display wait")
	for slot in 4:
		t.equal(game.progress_of(slot), 0, "restart clears progress")
		t.equal(game.mistakes_of(slot), 0, "restart clears mistakes")
		t.equal(game._last_pad[slot], -1, "restart clears prior pad entry")
	for pad in game._pads:
		t.equal(pad.mesh.material_override.albedo_color, UIKit.PANEL_HI, "restart clears illuminated pads")
	game._stage = game.Stage.INPUT
	game._timer = 30.0
	game._flash(0)
	await host.get_tree().create_timer(0.5).timeout
	t.equal(game._pads[0].mesh.material_override.albedo_color, UIKit.ACCENT, "wall time cannot expire a paused simulation flash")
	game.tick(0.0)
	t.equal(game._pads[0].mesh.material_override.albedo_color, UIKit.ACCENT, "zero delta preserves flash")
	game.tick(game._step_time)
	t.equal(game._pads[0].mesh.material_override.albedo_color, UIKit.PANEL_HI, "simulation time expires flash")
	game.on_round_start()
	game._sequence.assign([0])
	game._stage = game.Stage.INPUT
	for slot in 4:
		scene.ctx.set_score(slot, 0)
		scene.ctx.fighter(slot).global_position = game.pad_position(0)
	game._read_inputs()
	for slot in 4:
		t.equal(scene.ctx.scores[slot], 7, "same-tick sequence finish shares first-place bonus")
	game._read_inputs()
	for slot in 4:
		t.equal(scene.ctx.scores[slot], 7, "completed sequence cannot score twice")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
