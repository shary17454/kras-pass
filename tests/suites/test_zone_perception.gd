extends RefCounted

class SteeringProbe extends "res://src/ai/brains/zone_brain.gd":
	var destination := Vector3.INF
	func steer_to(target: Vector3, _urgency: float = 1.0) -> void:
		destination = target


func run(t: TestHarness, host: Node) -> void:
	t.suite("zone visible delayed movement")
	for difficulty in 4:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("zone_hold", ["fanoos", "nabta", "ramla", "sakhra"], 0, difficulty, 721), "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		for body in scene.ctx.fighters:
			body.set_physics_process(false)
		scene.ctx.observation_camera = null
		for slot in range(1, 4):
			scene.ctx.fighter(slot).hide()
		var game = scene.controller
		var p0 := Vector3(0, 0, 10.0)
		var p1 := Vector3(-10, 0, 0)
		var p2 := Vector3(0, 0, -10)
		game.zone_position = p0
		game._marker.global_position = p0
		scene.ctx.fighter(0).global_position = Vector3(scene.arena.def.radius * 0.72, 0.8, 0)
		var brain := SteeringProbe.new()
		brain.configure(0, scene.ctx, difficulty, 721)
		brain.controller = game
		brain.on_round_start()
		brain._time = 10.0
		game._marker.hide()
		brain.decide(0.01)
		t.equal(brain.destination, Vector3.INF, "tier %d does not steer toward unseen zone" % difficulty)
		game._marker.show()
		brain.destination = Vector3.INF
		brain.decide(0.01)
		t.equal(brain.destination, Vector3.INF, "tier %d first observation waits for reaction" % difficulty)
		brain._time = 10.0 + brain.reaction_time - 0.0001
		brain.destination = Vector3.INF
		brain.decide(0.01)
		t.equal(brain.destination, Vector3.INF, "tier %d cannot expire reaction early" % difficulty)
		brain._time = 10.0 + brain.reaction_time
		game.zone_position = p1
		game._marker.global_position = p1
		brain.decide(0.01)
		t.equal(brain.destination, p0, "tier %d moving-zone choice uses delayed position" % difficulty)
		brain._time = 10.0 + 2.0 * brain.reaction_time
		game.zone_position = p2
		game._marker.global_position = p2
		brain.decide(0.01)
		t.equal(brain.destination, p1, "tier %d later movement remains delayed" % difficulty)
		game._marker.hide()
		game.zone_position = Vector3(8, 0, 8)
		game._marker.global_position = game.zone_position
		brain._time += 1.0
		brain.destination = Vector3.INF
		brain.decide(0.01)
		t.equal(brain.destination, Vector3.INF, "tier %d hidden movement cannot update target" % difficulty)
		game._marker.show()
		brain.destination = Vector3.INF
		brain.decide(0.01)
		t.equal(brain.destination, Vector3.INF, "tier %d reacquisition earns no prior reaction credit" % difficulty)
		brain._time += brain.reaction_time
		brain.decide(0.01)
		t.equal(brain.destination, game._marker.global_position, "tier %d reacquired zone becomes actionable after delay" % difficulty)
		brain.on_round_start()
		brain.destination = Vector3.INF
		brain.decide(0.01)
		t.equal(brain.destination, Vector3.INF, "tier %d restart clears prior zone observations" % difficulty)
		brain.on_round_start()
		game.zone_radius = 9.0
		game._marker.scale = Vector3(0.6, 1, 0.6)
		t.ok(brain._perceived_zone().is_empty(), "tier %d rendered radius waits for reaction" % difficulty)
		brain._time += brain.reaction_time
		var observed: Dictionary = brain._perceived_zone()
		t.near(float(observed.get("radius", -1)), game.BASE_RADIUS * 0.6, 0.0001, "tier %d observes rendered scale instead of private capture radius" % difficulty)
		var original: Node3D = game._marker
		var replacement: Node3D = original.duplicate()
		scene.ctx.world_root.add_child(replacement)
		replacement.global_transform = original.global_transform
		game._marker = replacement
		t.ok(brain._perceived_zone().is_empty(), "tier %d replacement cue cannot borrow old history" % difficulty)
		brain._time += brain.reaction_time
		observed = brain._perceived_zone()
		t.equal(int(observed.get("id", 0)), replacement.get_instance_id(), "tier %d replacement becomes independently observable" % difficulty)
		for sample in AIBrain.HISTORY_CAP * 3:
			brain._time += 0.05
			brain._perceived_zone()
		t.equal(brain._zone_history.size(), AIBrain.HISTORY_CAP, "tier %d zone history remains bounded" % difficulty)
		game._marker = original
		replacement.queue_free()
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
