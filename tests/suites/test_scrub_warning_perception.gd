extends RefCounted

class AvoidProbe extends "res://src/ai/brains/saboteur_painter_brain.gd":
	var avoidance_requests := 0
	func steer_away(_target: Vector3, _urgency: float = 1.0) -> void:
		avoidance_requests += 1


func run(t: TestHarness, host: Node) -> void:
	t.suite("scrub warning observation and reaction")
	for difficulty in 4:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("mukharrib", ["fanoos", "nabta", "ramla", "sakhra"], 0, difficulty, 719), "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		for body in scene.ctx.fighters:
			body.set_physics_process(false)
		scene.ctx.observation_camera = null
		var game = scene.controller
		var centre: ArenaTile
		for tile: ArenaTile in game._tiles:
			tile.set_physics_process(false)
			tile.owner_slot = -1
			if tile.grid_x == 0 and tile.grid_z == 0:
				centre = tile
		t.ok(is_instance_valid(centre), "warning fixture has central ground")
		if not is_instance_valid(centre):
			scene.teardown()
			scene.queue_free()
			await host.get_tree().process_frame
			continue
		centre.owner_slot = 0
		game._choose_target()
		scene.ctx.fighter(0).global_position = centre.global_position + Vector3(0.5, 0.8, 0)
		var brain := AvoidProbe.new()
		brain.configure(0, scene.ctx, difficulty, 719)
		brain.controller = game
		brain.edge_awareness = 1.0
		brain.on_round_start()
		for marker: Node3D in game._markers:
			marker.hide()
		brain._time = 10.0
		brain.decide(0.01)
		t.equal(brain.avoidance_requests, 0, "tier %d cannot locate hidden scrub warning" % difficulty)
		for marker: Node3D in game._markers:
			marker.show()
		brain.decide(0.01)
		t.equal(brain.avoidance_requests, 0, "tier %d does not react on first observation" % difficulty)
		brain._time = 10.0 + brain.reaction_time - 0.0001
		brain.decide(0.01)
		t.equal(brain.avoidance_requests, 0, "tier %d retains complete warning reaction delay" % difficulty)
		brain._time = 10.0 + brain.reaction_time
		brain.decide(0.01)
		t.equal(brain.avoidance_requests, 1, "tier %d reacts at its warning deadline" % difficulty)
		for marker: Node3D in game._markers:
			marker.hide()
		brain._time += 1.0
		brain.decide(0.01)
		t.equal(brain.avoidance_requests, 1, "tier %d cannot update hidden danger after observing it" % difficulty)
		for marker: Node3D in game._markers:
			marker.show()
		brain.decide(0.01)
		t.equal(brain.avoidance_requests, 1, "tier %d reacquisition starts a new warning delay" % difficulty)
		brain._time += brain.reaction_time
		brain.decide(0.01)
		t.equal(brain.avoidance_requests, 2, "tier %d can avoid reacquired danger after delay" % difficulty)
		game._choose_target()
		brain.decide(0.01)
		t.equal(brain.avoidance_requests, 2, "tier %d new warning at same position has no old reaction credit" % difficulty)
		brain._time += brain.reaction_time
		brain.decide(0.01)
		t.equal(brain.avoidance_requests, 3, "tier %d new warning becomes actionable independently" % difficulty)
		brain.on_round_start()
		brain.decide(0.01)
		t.equal(brain.avoidance_requests, 3, "tier %d restart clears warning reaction credit" % difficulty)
		game._clear_markers()
		brain._time += 1.0
		brain.decide(0.01)
		t.equal(brain.avoidance_requests, 3, "tier %d missing rendered marker cannot reveal logical target" % difficulty)
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
