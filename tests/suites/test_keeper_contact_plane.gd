extends RefCounted


class KeeperProbe extends "res://src/ai/brains/keeper_brain.gd":
	var observed: Dictionary
	var ball: GameBall
	var target := Vector3.INF
	func _most_dangerous_ball() -> GameBall:
		return ball
	func perceive_ball(_ball: GameBall) -> Dictionary:
		return observed
	func steer_to(point: Vector3, _urgency: float = 1.0) -> void:
		target = point


class ThreatProbe extends "res://src/ai/brains/keeper_brain.gd":
	var observations := {}
	var hidden: GameBall
	func can_observe(node: Node3D) -> bool:
		return node != hidden and observations.has(node.get_instance_id())
	func perceive_ball(ball: GameBall) -> Dictionary:
		return observations.get(ball.get_instance_id(), {})


func run(t: TestHarness, host: Node) -> void:
	t.suite("keeper contact plane")
	var cfg := MatchConfig.build("goal_guard", ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 581)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_result): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	for slot in 4:
		t.test("oblique shot uses the actual contact plane on side %d" % slot)
		game.on_round_start()
		game.tick(0.0)
		var brain := KeeperProbe.new()
		brain.controller = game
		brain.configure(slot, scene.ctx, 3, 883)
		brain.prediction = 1.0
		brain.ball = game.balls[0]
		var normal: Vector3 = game.NORMALS[game.side_for(slot)]
		var axis: Vector3 = brain._goal_axis
		var position: Vector3 = brain._goal_pos + normal * 8.0 - axis * 6.0 + Vector3.UP * 0.9
		var velocity: Vector3 = -normal * 8.0 + axis * 16.0
		brain.observed = {"position": position, "velocity": velocity, "radius": brain.ball.visible_radius()}
		# Actual contact geometry is independent of the AI's prediction formula.
		var paddle: Vector3 = game.paddles[slot].global_position
		var arrival: float = ((paddle - position).dot(normal) + brain.ball.radius) / velocity.dot(normal)
		var contact: Vector3 = position + velocity * arrival
		brain.ball.velocity = Vector3(999, 0, 999)
		brain.decide(0.1)
		t.near((brain.target - brain._goal_pos).dot(axis), (contact - brain._goal_pos).dot(axis), 0.0001,
			"predicted lane coordinate matches the sphere touching the shield, not the player centre")
		var fighter: Fighter = scene.ctx.fighter(slot)
		fighter.global_position = brain.target + Vector3.UP * 1.3
		fighter._attack_time = 0.0
		game.tick(0.0)
		brain.ball.launch(position, velocity.normalized(), velocity.length())
		game._defend_ball(brain.ball, arrival + 0.001)
		t.equal(brain.ball.last_toucher, slot, "AI's chosen lane position actually intercepts the same oblique shot")
		brain.controller = null
	for slot in 4:
		t.test("keeper prioritizes observed arrival on side %d" % slot)
		var brain := ThreatProbe.new()
		brain.controller = game
		brain.configure(slot, scene.ctx, 3, 883)
		var slow := GameBall.new()
		var fast := GameBall.new()
		scene.ctx.world_root.add_child(slow)
		scene.ctx.world_root.add_child(fast)
		slow.add_to_group("balls")
		fast.add_to_group("balls")
		var normal: Vector3 = brain._goal_normal
		var contact: Vector3 = brain._goal_pos + normal * game.keeper_contact_offset(0.4)
		brain.observations[slow.get_instance_id()] = {"position": contact + normal * 2.0,
			"velocity": -normal * 0.5, "radius": 0.4}
		brain.observations[fast.get_instance_id()] = {"position": contact + normal * 7.0,
			"velocity": -normal * 14.0, "radius": 0.4}
		fast.velocity = normal * 999.0
		t.equal(brain._most_dangerous_ball(), fast, "half-second visible threat beats a closer four-second ball; private velocity is ignored")
		brain.hidden = fast
		t.equal(brain._most_dangerous_ball(), slow, "hidden fast threat cannot affect selection")
		brain.hidden = null
		brain.observations[fast.get_instance_id()]["position"] = contact + normal * 7.0 + brain._goal_axis * 100.0
		t.equal(brain._most_dangerous_ball(), slow, "trajectory missing this goal does not outrank an incoming goal threat")
		brain.observations[fast.get_instance_id()]["position"] = contact + normal * 7.0
		brain.observations[fast.get_instance_id()]["velocity"] = normal * 14.0
		t.equal(brain._most_dangerous_ball(), slow, "departing ball does not outrank an incoming goal threat")
		slow.queue_free()
		fast.queue_free()
		brain.controller = null
		await host.get_tree().process_frame
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
