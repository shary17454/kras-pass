extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("hurdle boundaries and finish lifecycle")
	var cfg := MatchConfig.build("hurdle_dash", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 116)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var arena: Arena = scene.arena
	var game = scene.controller
	var half_width: float = arena.def.radius * 0.7
	var half_length: float = arena.track_length * 0.5
	t.ok(arena.is_inside(arena.global_position + Vector3(half_width - 0.1, 0, 0)), "outer lane lies on authored floor")
	t.near(arena.edge_distance(arena.global_position + Vector3(half_width - 0.1, 0, 0)), 0.1, 0.001, "side edge matches floor width")
	t.ok(not arena.is_inside(arena.global_position + Vector3(0, 0, half_length - 0.1), 0.5), "end margin is respected")
	t.near(arena.edge_distance(arena.global_position + Vector3(0, 0, half_length + 1)), -1, 0.001, "end of track is a real edge")
	game.on_round_start()
	var fighter: Fighter = scene.ctx.fighter(0)
	for position in [Vector3(half_width + 5, 1, arena.finish_z - 1), Vector3(0, -5, arena.finish_z - 1), Vector3(0, 1, -half_length - 5)]:
		fighter.global_position = arena.global_position + position
		game.tick(0.01)
		t.equal(game.finish_times[0], game.UNFINISHED, "off-track or fallen runner cannot finish")
	fighter.global_position = arena.global_position + Vector3(0, 1, arena.finish_z - 0.2)
	scene.ctx.alive[0] = false
	game.tick(0.01)
	t.equal(game.finish_times[0], game.UNFINISHED, "spectator cannot finish")
	scene.ctx.alive[0] = true
	game.tick(0.01)
	var finish: int = game.finish_times[0]
	t.ok(finish < game.UNFINISHED, "valid crossing records finish")
	game.tick(0.01)
	t.equal(game.finish_times[0], finish, "finish time is immutable")
	t.equal(game._finished, 1, "finish is counted once")
	t.ok(not fighter.control_enabled, "finished runner stops accepting input")
	game.on_round_start()
	t.equal(game.hud_banner(), "0.00", "round resets visible elapsed time")
	for z in [-1000.0, 1000.0]:
		fighter.global_position = arena.global_position + Vector3(0, -20, z)
		game.on_fighter_fell(0)
		t.ok(arena.is_inside(fighter.global_position, 0.5), "rescue returns inside track")
		t.ok(fighter.global_position.z > game.finish_line_z(), "rescue cannot grant a finish")
	game.finish_times.assign([100, 200, 200, 300])
	t.ok(not game.is_tied(), "lower-place tie is not a winning tie")
	game.finish_times.assign([100, 100, 200, 300])
	t.ok(game.is_tied(), "joint fastest runners tie")
	game.finish_times.fill(game.UNFINISHED)
	t.ok(game.is_tied(), "all unfinished runners tie")
	scene.ctx.alive.assign([true, true, false, false])
	game.finish_times.assign([100, 110, game.UNFINISHED, game.UNFINISHED])
	t.ok(game.is_round_over(), "inactive spectators do not stall final contenders")
	game.finish_times[1] = game.UNFINISHED
	t.ok(not game.is_round_over(), "active unfinished runner keeps race open")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
