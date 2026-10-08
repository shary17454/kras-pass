extends RefCounted

class RoutingProbe extends "res://src/ai/brains/platform_brain.gd":
	var observations := 0
	func can_observe(node: Node3D) -> bool:
		observations += 1
		return is_instance_valid(node) and node.is_visible_in_tree()


func run(t: TestHarness, host: Node) -> void:
	t.suite("platform visible ground routing")
	await _test_safe_first_step(t, host)
	await _test_edge_support(t, host)
	await _test_arrival_control(t, host)
	await _test_walk_before_jump(t, host)
	await _test_equal_routes(t, host)
	await _test_equal_shortest_paths(t, host)
	var arena := Arena.new()
	host.add_child(arena)
	var body := Fighter.new()
	arena.add_child(body)
	body.set_physics_process(false)
	var ctx := MatchContext.new()
	ctx.arena = arena
	ctx.config = MatchConfig.build("crumble_court", ["fanoos"], 0, 1, 734)
	ctx.fighters.append(body)
	var brain := RoutingProbe.new()
	brain.configure(0, ctx, 3, 734)
	brain.accuracy = 1.0
	var start := _tile(arena, 0, 0, ArenaTile.State.WARNING)
	_tile(arena, 1, 0, ArenaTile.State.GONE)
	_tile(arena, 2, 0, ArenaTile.State.SOLID)
	t.ok(brain._pick_tile(arena, start.global_position) == null,
		"an isolated solid tile across a hole is not a walking destination")
	var step := _tile(arena, 0, 1, ArenaTile.State.SOLID)
	_tile(arena, 1, 1, ArenaTile.State.SOLID)
	_tile(arena, 2, 1, ArenaTile.State.SOLID)
	var picked := brain._pick_tile(arena, start.global_position)
	t.ok(picked == step, "take the first cardinal step along the intact detour")
	step.state = ArenaTile.State.WARNING
	t.ok(brain._pick_tile(arena, start.global_position) == step,
		"visible shaking ground remains a traversable step until it falls")
	step.state = ArenaTile.State.SOLID
	step.visible = false
	t.ok(brain._pick_tile(arena, start.global_position) == null,
		"a hidden intermediate tile cannot connect an otherwise visible island")
	step.visible = true
	step.state = ArenaTile.State.FALLING
	t.ok(brain._pick_tile(arena, start.global_position) == null,
		"falling tiles cannot connect the route even before they disappear")
	body.position = Vector3(4.0, 0.0, 0.0)
	arena.tiles[2].state = ArenaTile.State.WARNING
	arena.tiles[5].state = ArenaTile.State.GONE
	brain._target_tile = null
	brain.decide(0.1)
	t.equal(brain.move, Vector2.ZERO, "no visible walking route does not steer across holes toward the arena origin")
	for tile in arena.tiles:
		tile.state = ArenaTile.State.SOLID
		tile.show()
	brain.observations = 0
	brain._pick_tile(arena, start.global_position)
	t.ok(brain.observations <= arena.tiles.size() + 1,
		"one planning decision observes each floor tile at most once plus its origin")
	t.ok(brain._solid_neighbours(arena, start) > 0.0, "visible adjacent tiles contribute to the neighbour score")
	for tile in arena.tiles:
		if tile != start:
			tile.hide()
	t.equal(brain._solid_neighbours(arena, start), 0.0,
		"a new decision cannot reuse tiles that have since become hidden")
	start.build(2.0, 0.5, Color.GRAY)
	body.position = Vector3(0.0, 0.01, 0.0)
	for i in 12:
		await host.get_tree().physics_frame
		body.velocity = Vector3(0.0, -1.0, 0.0)
		body.move_and_slide()
	t.ok(body.is_on_floor(), "jump fixture contacts a real tile collider")
	start.state = ArenaTile.State.WARNING
	brain.edge_awareness = 1.0
	brain.reaction_time = 0.25
	brain._time = 1.0
	brain.bits = 0
	brain.decide(0.1)
	t.equal(brain.bits & InputFrame.Btn.JUMP, 0, "a new visible warning respects the reaction delay")
	brain._time += 0.26
	brain.decide(0.1)
	t.ok((brain.bits & InputFrame.Btn.JUMP) != 0, "visible shaking ground prompts a grounded bot to jump")
	var frame := InputFrame.new()
	frame.bits = brain.bits
	body._handle_buttons(frame)
	t.ok(body.velocity.y > 0.0, "the bot request uses the ordinary fighter jump impulse")
	start.hide()
	brain.bits = 0
	brain.decide(0.1)
	t.equal(brain.bits & InputFrame.Btn.JUMP, 0, "hidden floor state cannot prompt a jump")
	start.show()
	brain.bits = 0
	brain.decide(0.1)
	t.equal(brain.bits & InputFrame.Btn.JUMP, 0, "a newly visible warning does not reuse hidden observation credit")
	start.state = ArenaTile.State.SOLID
	brain.bits = 0
	brain.decide(0.1)
	t.equal(brain.bits & InputFrame.Btn.JUMP, 0, "solid floor does not prompt a panic jump")
	start.state = ArenaTile.State.WARNING
	body.can_jump = false
	brain.bits = 0
	brain.decide(0.1)
	t.equal(brain.bits & InputFrame.Btn.JUMP, 0, "disabled jump capability is respected")
	brain.on_round_start()
	t.ok(brain._warning_tile == null and brain._target_tile == null, "round restart clears floor observation and routing state")
	arena.queue_free()
	await host.get_tree().process_frame


func _test_safe_first_step(t: TestHarness, host: Node) -> void:
	var arena := Arena.new()
	host.add_child(arena)
	var body := Fighter.new()
	arena.add_child(body)
	body.set_physics_process(false)
	var ctx := MatchContext.new()
	ctx.arena = arena
	ctx.config = MatchConfig.build("crumble_court", ["fanoos"], 0, 3, 734)
	ctx.fighters.append(body)
	var brain := RoutingProbe.new()
	brain.configure(0, ctx, 3, 734)
	brain.edge_awareness = 1.0
	var start := _tile(arena, 0, 0, ArenaTile.State.WARNING)
	var fresh := _tile(arena, -1, 0, ArenaTile.State.SOLID)
	var shaking := _tile(arena, 1, 0, ArenaTile.State.WARNING)
	for x in range(2, 5):
		for z in range(-1, 2):
			_tile(arena, x, z, ArenaTile.State.SOLID)
	t.equal(brain._pick_tile(arena, start.global_position), fresh,
		"fresh immediate ground beats a dense island reached over shaking ground")
	fresh.state = ArenaTile.State.GONE
	t.equal(brain._pick_tile(arena, start.global_position), shaking,
		"shaking ground is still a last-resort route when no fresh first step exists")
	shaking.hide()
	t.equal(brain._pick_tile(arena, start.global_position), null,
		"hidden shaking ground cannot be used as an emergency route")
	arena.queue_free()
	await host.get_tree().process_frame


func _test_edge_support(t: TestHarness, host: Node) -> void:
	var arena := Arena.new()
	host.add_child(arena)
	var fresh := _tile(arena, -1, 0, ArenaTile.State.SOLID)
	var support := _tile(arena, 0, 0, ArenaTile.State.WARNING)
	var gone := _tile(arena, 1, 0, ArenaTile.State.FALLING)
	for tile in [fresh, support, gone]:
		tile.build(2.0, 0.5, Color.GRAY)
	gone.set_collision_layer_value(1, false)
	var body := Fighter.new()
	arena.add_child(body)
	body.set_physics_process(false)
	body.position = Vector3(1.1, 0.01, 0.0)
	for tick in 12:
		await host.get_tree().physics_frame
		body.velocity = Vector3(0.0, -1.0, 0.0)
		body.move_and_slide()
	t.ok(body.is_on_floor(), "edge fixture has actual native floor support")
	t.equal(arena.tile_at(body.global_position), gone, "nearest centre can be a falling tile beside the supporting collider")
	var ctx := MatchContext.new()
	ctx.arena = arena
	ctx.config = MatchConfig.build("crumble_court", ["fanoos"], 0, 3, 734)
	ctx.fighters.append(body)
	var brain := RoutingProbe.new()
	brain.configure(0, ctx, 3, 734)
	brain.edge_awareness = 1.0
	t.equal(brain._pick_tile(arena, body.global_position), fresh,
		"a grounded capsule can route from its visible supporting tile at a missing neighbour's edge")
	brain.decide(0.1)
	t.equal(brain._warning_tile, support, "warning observation follows actual visible ground contact")
	support.hide()
	t.equal(brain._pick_tile(arena, body.global_position), null, "hidden contact cannot become a route origin")
	support.show()
	body.position.y = 4.0
	t.equal(brain._pick_tile(arena, body.global_position), null, "stale contact cannot plan from a different fighter position")
	arena.queue_free()
	await host.get_tree().process_frame


func _test_arrival_control(t: TestHarness, host: Node) -> void:
	var arena := Arena.new()
	host.add_child(arena)
	var start := _tile(arena, 0, 0, ArenaTile.State.SOLID)
	var destination := _tile(arena, 1, 0, ArenaTile.State.SOLID)
	for tile in [start, destination]:
		tile.build(2.0, 0.5, Color.GRAY)
	var body := Fighter.new()
	arena.add_child(body)
	body.set_physics_process(false)
	body.position = Vector3(1.8, 0.01, 0.0)
	for tick in 12:
		await host.get_tree().physics_frame
		body.velocity = Vector3(0.0, -1.0, 0.0)
		body.move_and_slide()
	t.ok(body.is_on_floor(), "arrival fixture uses ordinary grounded fighter physics")
	var ctx := MatchContext.new()
	ctx.arena = arena
	ctx.config = MatchConfig.build("crumble_court", ["fanoos"], 0, 1, 734)
	ctx.fighters.append(body)
	var brain := RoutingProbe.new()
	brain.configure(0, ctx, 1, 734)
	brain.accuracy = 1.0
	brain.edge_awareness = 0.0
	brain.decision_interval = 0.4
	brain._target_tile = destination
	brain.decide(0.1)
	t.ok(brain.move.x > 0.0 and brain.move.length() < 0.2,
		"near a tile centre, analog arrival does not keep requesting full speed")
	var arrival_input := Vector3(brain.move.x, 0.0, brain.move.y)
	for tick in 28:
		await host.get_tree().physics_frame
		body._integrate_walk(arrival_input, 1.0 / 60.0)
		body.move_and_slide()
	t.ok(body.is_on_floor() and absf(body.position.x - 2.0) < 0.6,
		"held arrival input stays on its destination through the next decision horizon")
	t.equal(arena.tile_at(body.global_position), destination,
		"arrival cannot coast into a missing neighbouring tile")
	body.position = Vector3(-3.0, 0.0, 0.0)
	body.velocity = Vector3.ZERO
	brain.decide(0.1)
	t.ok(brain.move.length() > 0.99, "distant visible ground retains full movement input")
	body.position = Vector3(1.8, 0.0, 0.0)
	brain.decision_interval = 0.1
	brain.decide(0.1)
	var short_horizon := brain.move.length()
	brain.decision_interval = 0.4
	brain.decide(0.1)
	t.ok(brain.move.length() < short_horizon,
		"slower decision frequency accounts for longer held input, not extra speed")
	destination.hide()
	brain.decide(0.1)
	t.equal(brain.move, Vector2.ZERO, "hidden arrival target cannot keep directing the player")
	arena.queue_free()
	await host.get_tree().process_frame


func _test_walk_before_jump(t: TestHarness, host: Node) -> void:
	var arena := Arena.new()
	host.add_child(arena)
	var start := _tile(arena, 0, 0, ArenaTile.State.WARNING)
	start.build(2.0, 0.5, Color.GRAY)
	var fresh := _tile(arena, -1, 0, ArenaTile.State.SOLID)
	var shaking := _tile(arena, 1, 0, ArenaTile.State.WARNING)
	_tile(arena, 2, 0, ArenaTile.State.SOLID)
	var body := Fighter.new()
	arena.add_child(body)
	body.set_physics_process(false)
	body.position = Vector3(0.0, 0.01, 0.0)
	for tick in 12:
		await host.get_tree().physics_frame
		body.velocity = Vector3(0.0, -1.0, 0.0)
		body.move_and_slide()
	t.ok(body.is_on_floor(), "walk-or-jump fixture has actual grounded contact")
	var ctx := MatchContext.new()
	ctx.arena = arena
	ctx.config = MatchConfig.build("crumble_court", ["fanoos"], 0, 3, 734)
	ctx.fighters.append(body)
	var brain := RoutingProbe.new()
	brain.configure(0, ctx, 3, 734)
	brain.edge_awareness = 1.0
	brain.reaction_time = 0.25
	brain._time = 1.0
	brain.decide(0.1)
	brain._time += 0.26
	brain.bits = 0
	brain.decide(0.1)
	t.equal(brain._target_tile, fresh, "escape decision keeps its fresh visible first step")
	t.equal(brain.bits & InputFrame.Btn.JUMP, 0,
		"visible fresh walking route avoids an unnecessary panic jump after reaction delay")
	fresh.state = ArenaTile.State.WARNING
	brain.bits = 0
	brain.decide(0.1)
	t.equal(brain._target_tile, shaking, "only a shaking first step remains traversable")
	t.ok((brain.bits & InputFrame.Btn.JUMP) != 0,
		"a shaking escape route still allows an ordinary grounded rescue jump")
	brain.on_round_start()
	shaking.hide()
	brain._time = 2.0
	brain.bits = 0
	brain.decide(0.1)
	t.equal(brain.bits & InputFrame.Btn.JUMP, 0,
		"losing a safe route does not bypass the new warning reaction clock")
	arena.queue_free()
	await host.get_tree().process_frame


func _test_equal_routes(t: TestHarness, host: Node) -> void:
	var arena := Arena.new()
	host.add_child(arena)
	var ctx := MatchContext.new()
	ctx.arena = arena
	ctx.config = MatchConfig.build("crumble_court", ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 734)
	for slot in 4:
		var body := Fighter.new()
		arena.add_child(body)
		body.set_physics_process(false)
		body.hide()
		ctx.fighters.append(body)
	_tile(arena, 0, 0, ArenaTile.State.WARNING)
	var left := _tile(arena, -1, 0, ArenaTile.State.SOLID)
	var right := _tile(arena, 1, 0, ArenaTile.State.SOLID)
	for slot in 4:
		var counts := [0, 0]
		for seed_value in range(1000, 1128):
			var brain := RoutingProbe.new()
			brain.configure(slot, ctx, 3, seed_value)
			var pick := brain._pick_tile(arena, Vector3.ZERO)
			t.ok(pick in [left, right], "equal route remains an intact cardinal step")
			counts[0 if pick == left else 1] += 1
			var repeated := RoutingProbe.new()
			repeated.configure(slot, ctx, 3, seed_value)
			t.equal(repeated._pick_tile(arena, Vector3.ZERO), pick, "same seed and seat reproduce the route tie")
		t.ok(counts[0] >= 40 and counts[1] >= 40, "seat %d does not always choose the first equal route: %s" % [slot, counts])
	var unique := RoutingProbe.new()
	unique.configure(0, ctx, 3, 734)
	left.hide()
	var rng_before := unique.rng.state
	t.equal(unique._pick_tile(arena, Vector3.ZERO), right, "hidden equal route cannot enter tie selection")
	t.equal(unique.rng.state, rng_before, "a unique best route consumes no tie RNG")
	arena.queue_free()
	await host.get_tree().process_frame


func _test_equal_shortest_paths(t: TestHarness, host: Node) -> void:
	for quarter in 4:
		var arena := Arena.new()
		host.add_child(arena)
		var ctx := MatchContext.new()
		ctx.arena = arena
		ctx.config = MatchConfig.build("crumble_court", ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 734)
		for slot in 4:
			var body := Fighter.new()
			arena.add_child(body)
			body.set_physics_process(false)
			body.hide()
			ctx.fighters.append(body)
		var first: Array[ArenaTile] = []
		for cell in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 0), Vector2i(2, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)]:
			var rotated: Vector2i = cell
			for turn in quarter:
				rotated = Vector2i(-rotated.y, rotated.x)
			var state := ArenaTile.State.SOLID if cell == Vector2i(2, 2) else ArenaTile.State.WARNING
			var tile := _tile(arena, rotated.x, rotated.y, state)
			if cell in [Vector2i(1, 0), Vector2i(0, 1)]:
				first.append(tile)
		for slot in 4:
			var counts := [0, 0]
			for seed_value in range(1000, 1064):
				var brain := RoutingProbe.new()
				brain.configure(slot, ctx, 3, seed_value)
				var picked := brain._pick_tile(arena, Vector3.ZERO)
				t.ok(picked in first, "equal shortest path stays on a visible cardinal first step")
				if picked in first:
					counts[first.find(picked)] += 1
			t.ok(counts[0] >= 16 and counts[1] >= 16,
				"rotation %d seat %d can use both equally short routes to one destination: %s" % [quarter, slot, counts])
		var unique := RoutingProbe.new()
		unique.configure(0, ctx, 3, 734)
		first[0].hide()
		var before := unique.rng.state
		t.equal(unique._pick_tile(arena, Vector3.ZERO), first[1], "a hidden alternative cannot enter shortest-path tie selection")
		t.equal(unique.rng.state, before, "one remaining shortest route consumes no tie RNG")
		arena.queue_free()
		await host.get_tree().process_frame


func _tile(arena: Arena, x: int, z: int, state: ArenaTile.State) -> ArenaTile:
	var tile := ArenaTile.new()
	arena.add_child(tile)
	tile.grid_x = x
	tile.grid_z = z
	tile.position = Vector3(x * 2.0, 0.0, z * 2.0)
	tile.state = state
	arena.tiles.append(tile)
	return tile
