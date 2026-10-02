extends RefCounted

func run(t: TestHarness, host: Node) -> void:
	t.suite("runner contact jump recovery")
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": MatchConfig.build("hurdle_dash", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 1032434731), "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	for body in scene.ctx.fighters: body.set_physics_process(false)
	var fighter: Fighter = scene.ctx.fighter(3)
	fighter.global_position = Vector3(100, 1, 0)
	var obstacle := StaticBody3D.new()
	obstacle.collision_layer = 1
	obstacle.collision_mask = 0
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 4, 1.2)
	collider.shape = box
	obstacle.add_child(collider)
	scene.add_child(obstacle)
	obstacle.global_position = Vector3(100, 1, -1)
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	var brain = load("res://src/ai/brains/runner_brain.gd").new()
	brain.configure(3, scene.ctx, 2, 1032434731)
	brain.controller = scene.controller
	brain.accuracy = 1.0
	brain.dash_chance = 0.0
	t.near(brain._distance_to_obstacle(fighter), 0.4, 0.001, "physical ray sees close-contact hurdle")
	brain.decide(0.1)
	t.ok((brain.bits & InputFrame.Btn.JUMP) != 0, "contact cannot suppress recovery jump")
	obstacle.global_position.z = -20
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	brain.bits = 0
	brain.decide(0.1)
	t.ok(brain._distance_to_obstacle(fighter) < 0.0, "clear lane has no invented obstacle")
	t.ok((brain.bits & InputFrame.Btn.JUMP) == 0, "clear lane does not trigger recovery jump")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
