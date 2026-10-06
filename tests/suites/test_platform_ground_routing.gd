extends RefCounted

class RoutingProbe extends "res://src/ai/brains/platform_brain.gd":
	var observations := 0
	func can_observe(node: Node3D) -> bool:
		observations += 1
		return is_instance_valid(node) and node.is_visible_in_tree()


func run(t: TestHarness, host: Node) -> void:
	t.suite("platform visible ground routing")
	await _test_safe_first_step(t, host)
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


func _tile(arena: Arena, x: int, z: int, state: ArenaTile.State) -> ArenaTile:
	var tile := ArenaTile.new()
	arena.add_child(tile)
	tile.grid_x = x
	tile.grid_z = z
	tile.position = Vector3(x * 2.0, 0.0, z * 2.0)
	tile.state = state
	arena.tiles.append(tile)
	return tile
