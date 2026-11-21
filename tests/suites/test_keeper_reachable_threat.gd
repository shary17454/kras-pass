extends RefCounted


class KeeperProbe extends "res://src/ai/brains/keeper_brain.gd":
	var observations := {}
	func can_observe(node: Node3D) -> bool:
		return observations.has(node.get_instance_id())
	func perceive_ball(ball: GameBall) -> Dictionary:
		return observations.get(ball.get_instance_id(), {})


func run(t: TestHarness, host: Node) -> void:
	t.suite("keeper reachable threat selection")
	var cfg := MatchConfig.build("storm_heart", ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 92)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	game.on_round_start()
	game.tick(0.0)
	game._spawn_ball()
	var early: GameBall = game.balls[0]
	var later: GameBall = game.balls[1]
	for slot in 4:
		var brain := KeeperProbe.new()
		brain.controller = game
		brain.configure(slot, scene.ctx, 3, 819)
		brain.prediction = 1.0
		var normal: Vector3 = brain._goal_normal
		var axis: Vector3 = brain._goal_axis
		var plane: Vector3 = brain._goal_pos + normal * game.keeper_contact_offset(early.radius)
		brain.observations[early.get_instance_id()] = {
			"position": plane + normal * 4.0 - axis * brain._lane_limit * 0.9,
			"velocity": -normal * 20.0, "radius": early.radius, "age": 0.13}
		brain.observations[later.get_instance_id()] = {
			"position": plane + normal * 8.0 + axis * 3.0,
			"velocity": -normal * 8.0, "radius": later.radius, "age": 0.13}
		t.equal(brain._most_dangerous_ball(), later,
			"expert chooses a reachable save instead of an unreachable earlier shot")
		early.velocity = Vector3(999, 0, 999)
		later.velocity = Vector3(-999, 0, -999)
		t.equal(brain._most_dangerous_ball(), later, "target selection uses delayed observed motion, not private velocity")
		brain.prediction = 0.15
		t.equal(brain._most_dangerous_ball(), early, "low prediction retains simpler earliest-threat selection")
		brain.prediction = 1.0
		var observed_later: Dictionary = brain.observations[later.get_instance_id()]
		brain.observations.erase(later.get_instance_id())
		t.equal(brain._most_dangerous_ball(), early, "no reachable alternative still attempts the visible incoming shot")
		brain.observations[later.get_instance_id()] = observed_later
		var observed_early: Dictionary = brain.observations[early.get_instance_id()].duplicate()
		brain.observations[early.get_instance_id()] = {
			"position": plane + normal * 0.5,
			"velocity": -normal * 20.0, "radius": early.radius, "age": 0.13}
		for strength in [0.15, 1.0]:
			brain.prediction = strength
			t.equal(brain._most_dangerous_ball(), later,
				"expired observed crossing does not displace an upcoming save, side=%d prediction=%s" % [slot, strength])
		brain.prediction = 1.0
		brain.observations[early.get_instance_id()]["age"] = 0.0
		t.equal(brain._most_dangerous_ball(), early,
			"the same imminent crossing remains eligible when its observation is fresh, side=%d" % slot)
		brain.observations[early.get_instance_id()] = observed_early
		brain.observations.erase(early.get_instance_id())
		t.equal(brain._most_dangerous_ball(), later, "hidden threats are never added to the selection")
		var fighter: Fighter = scene.ctx.fighter(slot)
		var original_speed := fighter.top_speed
		fighter.top_speed = 10.0
		fighter.can_dash = false
		fighter.velocity = Vector3.ZERO
		var width: float = game.PADDLE_HALF * 1.25 + later.radius
		var crossing := fighter.global_position + axis * (width + 1.0)
		t.ok(brain._can_reach_crossing(crossing, 0.2, {"radius": later.radius, "age": 0.0}),
			"fresh observation retains a physically possible save")
		t.ok(not brain._can_reach_crossing(crossing, 0.2, {"radius": later.radius, "age": 0.13}),
			"travel budget subtracts the age of the delayed observation")
		fighter.can_dash = true
		fighter.charge = 1.0
		t.ok(brain._can_reach_crossing(crossing, 0.2, {"radius": later.radius, "age": 0.13}),
			"available dash keeps marginal saves eligible")
		fighter.charge = 0.0
		t.ok(not brain._can_reach_crossing(crossing, 0.2, {"radius": later.radius, "age": 0.13}),
			"empty personal dash meter does not grant imaginary travel")
		fighter.velocity = axis * 20.0
		t.ok(brain._can_reach_crossing(crossing, 0.2, {"radius": later.radius, "age": 0.13}),
			"existing personal momentum keeps possible saves eligible")
		fighter.top_speed = original_speed
		brain.controller = null
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
