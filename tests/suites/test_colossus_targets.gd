extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("colossus targets playable ground rather than airborne height")
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": MatchConfig.build("boss_colossus", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 345), "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	for body in scene.ctx.fighters: body.set_physics_process(false)
	var game: Node = scene.controller
	var arena: Arena = scene.arena
	var fighter: Fighter = scene.ctx.fighter(0)
	fighter.global_position = Vector3(6, 2, 0)
	scene.ctx.fighter(1).global_position = Vector3(0, -500, 0)
	scene.ctx.fighter(2).visible = false
	scene.ctx.fighter(3).alive = false
	t.equal(game._pick_target(), Vector3(6, 0, 0), "jumping target is projected onto actual floor")
	game._slam()
	t.equal(game._telegraphs.size(), 1, "eligible target creates one slam warning")
	if not game._telegraphs.is_empty():
		t.equal(game._telegraphs[0].pos, Vector3(6, 0, 0), "slam warning remains reachable at floor height")
	game._clear_telegraphs()
	fighter.global_position = Vector3(6, -0.6, 0)
	t.equal(game._pick_target(), Vector3.INF, "below-floor fighter cannot become slam target")
	game._slam()
	t.empty(game._telegraphs, "no targeted slam when all fighters are ineligible")
	game._sweep()
	t.equal(game._telegraphs.size(), 8, "authored radial sweep is independent of target eligibility")
	game._clear_telegraphs()
	fighter.global_position = Vector3(80, 0, 0)
	t.equal(game._pick_target(), Vector3.INF, "outside fighter cannot create unreachable opening")
	fighter.global_position = Vector3(6, 0, 0)
	scene.ctx.alive[0] = false
	t.equal(game._pick_target(), Vector3.INF, "eliminated slot cannot be targeted")
	scene.ctx.alive[0] = true
	game._open_crater(Vector3(6, 0, 0), 4.0)
	t.equal(game._pick_target(), Vector3.INF, "fighter above existing crater cannot become target")
	game._clear_craters()
	arena.global_position = Vector3(12, 7, -4)
	fighter.global_position = arena.global_position + Vector3(6, 2, 0)
	t.equal(game._pick_target(), arena.global_position + Vector3(6, 0, 0), "translated arena controls target floor height")
	game._slam()
	game._tick_telegraphs(2.0)
	t.near(game._fist.global_position.distance_to(arena.global_position + Vector3(6, 1, 0)), 0.0, 0.001, "buried fist follows translated floor")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
