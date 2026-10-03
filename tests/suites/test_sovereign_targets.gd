extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("sovereign targets active fighters on reachable ground")
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": MatchConfig.build("boss_sovereign", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 345), "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	for body in scene.ctx.fighters: body.set_physics_process(false)
	var game: Node = scene.controller
	var fighter: Fighter = scene.ctx.fighter(0)
	var arena: Arena = scene.arena
	fighter.global_position = arena.global_position + Vector3(6, 2, 0)
	scene.ctx.fighter(1).global_position = arena.global_position + Vector3(0, -500, 0)
	scene.ctx.fighter(2).global_position = arena.global_position
	scene.ctx.fighter(2).visible = false
	scene.ctx.fighter(3).global_position = arena.global_position
	scene.ctx.fighter(3).alive = false
	t.equal(game._closest_alive(), 0, "hidden, dead and below-floor slots cannot displace active target")
	game._lunge_timer = 0.0
	game._pursuit(0.0)
	t.equal(game._telegraphs.size(), 1, "pursuit creates one reachable warning")
	if not game._telegraphs.is_empty():
		t.equal(game._telegraphs[0].pos, arena.global_position + Vector3(6, 0, 0), "jumping target warning lies on floor")
	game._clear_telegraphs()
	game._collapse_timer = 0.0
	game._collapse(0.0)
	t.equal(game._telegraphs.size(), 6, "collapse marks one active fighter plus five authored radial hazards")
	for warning in game._telegraphs:
		t.near(warning.pos.y, arena.global_position.y, 0.001, "collapse warnings remain on floor")
		t.ok(arena.is_inside(warning.pos), "collapse warning centre remains inside arena")
	game._clear_telegraphs()
	fighter.global_position = arena.global_position + Vector3(80, 0, 80)
	t.equal(game._closest_alive(), -1, "no target while everyone is outside, dead, hidden or waiting")
	var previous: Vector3 = game.boss_node.global_position
	game._lunge_timer = 0.0
	game._pursuit(1.0)
	t.equal(game.boss_node.global_position, previous, "boss does not chase an unreachable target")
	t.empty(game._telegraphs, "no pursuit warning without an eligible fighter")
	game._collapse_timer = 0.0
	game._collapse(0.0)
	t.equal(game._telegraphs.size(), 5, "global collapse hazards still run without eligible fighter targets")
	game._clear_telegraphs()
	fighter.global_position = arena.global_position + Vector3(0, -0.6, 0)
	t.equal(game._closest_alive(), -1, "fighter falling beneath floor is excluded even inside horizontal bounds")
	fighter.global_position = arena.global_position + Vector3(6, 0, 0)
	scene.ctx.alive[0] = false
	t.equal(game._closest_alive(), -1, "eliminated match slot cannot be targeted")
	scene.ctx.alive[0] = true
	arena.global_position = Vector3(12, 7, -4)
	fighter.global_position = arena.global_position + Vector3(6, 2, 0)
	t.equal(game._closest_alive(), 0, "eligibility uses translated arena coordinates")
	game._lunge_timer = 0.0
	game._pursuit(0.0)
	if not game._telegraphs.is_empty():
		t.equal(game._telegraphs[0].pos, arena.global_position + Vector3(6, 0, 0), "warning uses translated floor height")
	else:
		t.ok(false, "translated active target still receives warning")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
