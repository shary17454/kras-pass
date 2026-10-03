extends RefCounted

func run(t: TestHarness, host: Node) -> void:
	t.suite("colossus visible safe attack approach")
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": MatchConfig.build("boss_colossus", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 345), "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	for body in scene.ctx.fighters: body.set_physics_process(false)
	var game: Node = scene.controller
	var fighter: Fighter = scene.ctx.fighter(0)
	var point := Vector3(4, 1, 0)
	game._fist.global_position = point
	game._open_crater(Vector3(4, 0, 0), 4.0)
	game._exposed = 1.0
	fighter.global_position = Vector3(7.55, 0, 0)
	var brain = load("res://src/ai/brains/boss_hunter_brain.gd").new()
	brain.configure(0, scene.ctx, 3, 172)
	brain.controller = game
	brain.edge_awareness = 1.0
	brain.accuracy = 1.0
	brain.attack_chance = 1.0
	brain.decide(0.1)
	t.ok((brain.bits & InputFrame.Btn.ATTACK) != 0, "bot attacks exposed fist from safe crater rim")
	t.ok(scene.arena.is_inside(fighter.global_position, 0.5), "attacking position remains on real ground")
	if game.has_method("attack_plan"):
		for step in 16:
			var angle := TAU * float(step) / 16.0
			var from := Vector3(4, 0, 0) + Vector3(cos(angle), 0, sin(angle)) * 6
			var plan: Dictionary = game.attack_plan(from)
			t.ok(not plan.is_empty(), "visible fist has approach from each direction")
			if not plan.is_empty():
				t.ok(scene.arena.is_inside(plan.target, 0.5), "approach target is outside all holes")
				t.ok(Vector2(plan.target.x - point.x, plan.target.z - point.z).length() <= 3.75, "approach target is within authored arm strike reach")
		var unsafe: Dictionary = game.attack_plan(Vector3(4, 0, 0))
		t.ok(unsafe.is_empty() or not unsafe.attack, "inside-hole position cannot authorize an attack")
		var high: Dictionary = game.attack_plan(Vector3(7.55, 9, 0))
		t.ok(high.is_empty() or not high.attack, "unreachable vertical offset cannot authorize an attack")
		game.telegraph(fighter.global_position - Vector3(1, 0, 0), 4.0, 2.0, func(_p, _r): pass)
		brain.bits = 0
		brain.decide(0.1)
		t.ok((brain.bits & InputFrame.Btn.ATTACK) == 0, "temporary slam warning takes priority over attacking")
		t.ok(brain.move.x > 0.0, "bot flees visible warning instead of approaching fist")
		game._clear_telegraphs()
		game._open_crater(Vector3(-2, 0, 0), 1.0)
		fighter.global_position = Vector3(-4, 0, 0)
		brain.bits = 0
		brain.decide(0.1)
		var origin: Vector3 = fighter.global_position - scene.arena.global_position
		var next: Vector3 = origin + Vector3(brain.move.x, 0, brain.move.y) * 1.2
		t.ok(brain.move.length() > 0.1, "bot finds a lateral step around an intervening crater")
		t.ok(scene.arena._crater_floor.path_clear(origin, next, 0.5), "bot approach step never crosses intervening carved ground")
		for sample in 12:
			brain.accuracy = 0.0
			brain.decide(0.1)
			next = origin + Vector3(brain.move.x, 0, brain.move.y) * 1.2
			t.ok(scene.arena._crater_floor.path_clear(origin, next, 0.5), "aim error never redirects a safe approach into the crater")
		brain.accuracy = 1.0
		game.telegraph(Vector3(-5, 0, 0), 4.0, 2.0, func(_p, _r): pass)
		brain.decide(0.1)
		next = origin + Vector3(brain.move.x, 0, brain.move.y) * 1.2
		t.ok(scene.arena._crater_floor.path_clear(origin, next, 0.5), "warning escape cannot run directly into another crater")
		game._exposed = 0.0
		t.empty(game.attack_plan(fighter.global_position), "no attack plan for unexposed fist")
	else:
		t.ok(false, "visible attack approach exists")
	# Respawn waiting slots stay alive in the match, not in the arena.
	for body in scene.ctx.fighters:
		body.global_position = Vector3(80, 20, 80)
	var valid_target := Vector3(-6, 1, 0)
	fighter.global_position = valid_target
	scene.ctx.fighter(1).global_position = Vector3(-4, 1, 0)
	scene.ctx.fighter(1).visible = false
	scene.ctx.fighter(2).global_position = Vector3(-3, 1, 0)
	scene.ctx.fighter(2).alive = false
	scene.ctx.fighter(3).global_position = Vector3(4, 1, 0)
	for sample in 32:
		t.equal(game._pick_target(), Vector3(valid_target.x, scene.arena.global_position.y, valid_target.z), "slam targets only visible active players on actual ground")
	fighter.global_position = Vector3(80, 20, 80)
	t.equal(game._pick_target(), Vector3.INF, "no unreachable slam when every player is falling or waiting")
	_dash_clearance(t, scene, brain)
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame


func _dash_clearance(t: TestHarness, scene: Node, brain) -> void:
	t.test("published dash input respects the entire carved-ground segment")
	var floor: Node = scene.arena._crater_floor
	floor.reset()
	floor.open_hole(Vector3.ZERO, 1.0)
	var fighter: Fighter = scene.ctx.fighter(0)
	fighter.global_position = scene.arena.global_position + Vector3(-3, 0, 0)
	brain.input_noise = 0.0
	brain.move = Vector2.RIGHT
	brain.bits = InputFrame.Btn.DASH | InputFrame.Btn.ATTACK
	brain._publish()
	var frame: InputFrame = InputRouter._virtual_pending[0]
	t.ok(floor.has_ground(Vector3(2, 0, 0), 0.5), "dash destination has ground; endpoint-only validation would miss this hole")
	t.ok((frame.bits & InputFrame.Btn.DASH) == 0, "a dash cannot cross a hole even if its endpoint is safe")
	t.ok((frame.bits & InputFrame.Btn.ATTACK) != 0, "ground filtering leaves attack input unchanged")
	brain.move = Vector2.UP
	brain.bits = InputFrame.Btn.DASH
	brain._publish()
	t.ok((frame.bits & InputFrame.Btn.DASH) != 0, "dash remains available along clear ground")
	brain.move = Vector2.ZERO
	fighter.facing = Vector3.RIGHT
	brain.bits = InputFrame.Btn.DASH
	brain._publish()
	t.ok((frame.bits & InputFrame.Btn.DASH) == 0, "neutral-stick dash uses the fighter's actual facing direction")
	fighter.facing = Vector3.FORWARD
	brain.bits = InputFrame.Btn.DASH
	brain._publish()
	t.ok((frame.bits & InputFrame.Btn.DASH) != 0, "neutral-stick clear-facing dash stays available")
	brain.input_noise = 1.5
	brain._noise_phase = PI / (2.0 * 1.7) - 0.09
	brain.bits = InputFrame.Btn.DASH
	brain._publish()
	t.ok((frame.bits & InputFrame.Btn.DASH) == 0, "clearance is checked after final input noise, not the earlier steering proposal")
	brain.input_noise = 0.0
	floor.reset()
	brain.move = Vector2.RIGHT
	brain.bits = InputFrame.Btn.DASH
	brain._publish()
	t.ok((frame.bits & InputFrame.Btn.DASH) != 0, "removing the hole restores dash without resetting the brain")
