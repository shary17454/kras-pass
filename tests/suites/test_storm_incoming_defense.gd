extends RefCounted


class StormProbe extends "res://src/ai/brains/storm_keeper_brain.gd":
	var observed: Dictionary
	var ball: GameBall
	var target := Vector3.INF
	func _most_dangerous_ball() -> GameBall:
		return ball
	func perceive_ball(_ball: GameBall) -> Dictionary:
		return observed
	func steer_to(point: Vector3, _urgency: float = 1.0) -> void:
		target = point


func run(t: TestHarness, host: Node) -> void:
	t.suite("storm incoming defense")
	var cfg := MatchConfig.build("storm_heart", ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 581)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_result): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	game.on_round_start()
	game.tick(0.0)
	game._windup = game.WINDUP_TIME
	for slot in 4:
		var brain := StormProbe.new()
		brain.controller = game
		brain.configure(slot, scene.ctx, 3, 883)
		brain.prediction = 1.0
		brain.strategy = 1.0
		brain.ball = game.balls[0]
		var normal: Vector3 = game.NORMALS[game.side_for(slot)]
		var axis: Vector3 = brain._goal_axis
		var position: Vector3 = brain._goal_pos + normal * 8.0 - axis * 3.0 + Vector3.UP * 0.9
		var velocity: Vector3 = -normal * 8.0 + axis * 2.0
		brain.observed = {"position": position, "velocity": velocity, "radius": brain.ball.visible_radius()}
		var paddle: Vector3 = game.paddles[slot].global_position
		var arrival: float = ((paddle - position).dot(normal) + brain.ball.radius) / velocity.dot(normal)
		var contact: Vector3 = position + velocity * arrival
		brain.ball.velocity = Vector3(999, 0, 999)
		brain.decide(0.1)
		brain._time += brain.reaction_time
		brain.decide(0.1)
		t.near((brain.target - brain._goal_pos).dot(axis), (contact - brain._goal_pos).dot(axis), 0.0001,
			"windup must not override delayed incoming interception on side %d" % slot)
		var fighter: Fighter = scene.ctx.fighter(slot)
		fighter.global_position = brain.target + Vector3.UP * 1.3
		fighter._attack_time = 0.0
		game.tick(0.0)
		brain.ball.launch(position, velocity.normalized(), velocity.length())
		game._defend_ball(brain.ball, arrival + 0.001)
		t.equal(brain.ball.last_toucher, slot, "warning interception actually defends the oblique shot")
		brain.observed.velocity = normal * 8.0
		brain.decide(0.1)
		t.near(brain.target.distance_to(brain._goal_pos), 0.0, 0.0001, "outgoing ball allows windup home positioning")
		brain.observed.velocity = -normal * 0.5
		brain.decide(0.1)
		t.near(brain.target.distance_to(brain._goal_pos), 0.0, 0.0001, "distant slow ball is not an imminent threat")
		brain.observed = {}
		brain.decide(0.1)
		t.near(brain.target.distance_to(brain._goal_pos), 0.0, 0.0001, "unobserved ball cannot override the warning")
		brain.ball = null
		brain.decide(0.1)
		t.near(brain.target.distance_to(brain._goal_pos), 0.0, 0.0001, "no visible ball retains warning home positioning")
		brain.controller = null
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
