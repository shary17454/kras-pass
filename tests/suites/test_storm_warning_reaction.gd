extends RefCounted

const Fixtures := preload("res://tests/suites/test_storm_incoming_defense.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("storm public warning reaction")
	var cfg := MatchConfig.build("storm_heart", ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 581)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_result): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	game.on_round_start()
	game.tick(0.0)
	for difficulty in 4:
		t.test("difficulty %d public cue lifecycle" % difficulty)
		var brain := Fixtures.StormProbe.new()
		brain.controller = game
		brain.configure(0, scene.ctx, difficulty, 883)
		brain.prediction = 1.0
		brain.strategy = 1.0
		brain.ball = game.balls[0]
		brain.observed = {"position": brain._goal_pos + brain._goal_normal * 8.0 + brain._goal_axis * 3.0,
			"velocity": brain._goal_normal * 8.0, "radius": brain.ball.visible_radius()}
		game._windup = 0.0
		brain._time = 10.0
		brain.decide(0.1)
		t.near((brain.target - brain._goal_pos).dot(brain._goal_axis), 3.0, 0.0001, "without warning keep normal ball tracking")
		game._windup = game.WINDUP_TIME
		brain.decide(0.1)
		t.near((brain.target - brain._goal_pos).dot(brain._goal_axis), 3.0, 0.0001, "new warning cannot trigger an immediate decision")
		brain._time = 10.0 + brain.reaction_time - 0.0001
		brain.decide(0.1)
		t.near((brain.target - brain._goal_pos).dot(brain._goal_axis), 3.0, 0.0001, "warning remains delayed before configured reaction time")
		brain._time = 10.0 + brain.reaction_time
		brain.decide(0.1)
		t.near(brain.target.distance_to(brain._goal_pos), 0.0, 0.0001, "public warning becomes actionable at reaction threshold")
		game._windup = 0.0
		brain.decide(0.1)
		t.near((brain.target - brain._goal_pos).dot(brain._goal_axis), 3.0, 0.0001, "expired warning no longer overrides tracking")
		game._windup = game.WINDUP_TIME
		brain.decide(0.1)
		t.near((brain.target - brain._goal_pos).dot(brain._goal_axis), 3.0, 0.0001, "next warning does not inherit old reaction credit")
		brain._time += brain.reaction_time
		brain.decide(0.1)
		t.near(brain.target.distance_to(brain._goal_pos), 0.0, 0.0001, "next warning receives its own reaction delay")
		brain.on_round_start()
		brain.decide(0.1)
		t.near((brain.target - brain._goal_pos).dot(brain._goal_axis), 3.0, 0.0001, "restart cannot retain the previous round's warning")
		brain._time += brain.reaction_time
		brain.decide(0.1)
		t.near(brain.target.distance_to(brain._goal_pos), 0.0, 0.0001, "new round still permits warning reaction after its delay")
		game._windup = 0.0
		brain.decide(0.1)
		game._windup = game.WINDUP_TIME
		brain.decide(0.1)
		game._windup = 0.0
		brain._time += brain.reaction_time * 2.0
		brain.decide(0.1)
		t.near((brain.target - brain._goal_pos).dot(brain._goal_axis), 3.0, 0.0001, "warning expiring before reaction never causes a late response")
		game._windup = game.WINDUP_TIME
		brain.decide(0.1)
		t.near((brain.target - brain._goal_pos).dot(brain._goal_axis), 3.0, 0.0001, "short expired warning cannot prime a later warning")
		brain.controller = null
		t.ok(not brain._perceives_warning(), "missing controller cannot retain a public cue")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
