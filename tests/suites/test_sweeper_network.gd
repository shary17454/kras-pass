extends RefCounted

const Replica = preload("res://src/net/match_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("sweeper network presentation")
	var cfg := MatchConfig.build("sweeper_storm", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 117)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	scene.controller.on_round_start()
	var arms: Array = []
	for hazard in scene.arena._hazards:
		if hazard is ArenaHazards.Sweeper:
			arms.append(hazard)
			t.near(hazard.resistance_influence, 0.25, 0.00001, "round sets the mode-specific bounded resistance influence")
			hazard.tick(3.0)
	var replica = Replica.new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	t.equal(arms.size(), 3, "authored arena has three arms")
	t.ok(replica.accept(packet, 4, "sweeper_storm"), "serialized angles accepted")
	for world in [{}, {"angles": []}, {"angles": [0, 0]}, {"angles": [0, 0, 0, 0]}, {"angles": [0, 0, 0], "extra": 1}]:
		var bad := packet.duplicate(true)
		bad.world = world
		t.ok(not replica.accept(bad, 4, "sweeper_storm"), "incomplete or extra state rejected")
	for angle in [-3.142, 3.142, NAN, INF, "1", true]:
		var bad := packet.duplicate(true)
		bad.world.angles[1] = angle
		t.ok(not replica.accept(bad, 4, "sweeper_storm"), "invalid angle rejected")
	var scores: Array = Array(scene.ctx.scores)
	var alive: Array = Array(scene.ctx.alive)
	scene.controller.on_round_start()
	for frame in 10:
		replica.render(scene, 0.016)
	for i in arms.size():
		t.ok(is_equal_approx(arms[i].rotation.y, float(packet.world.angles[i])), "host angle restored")
		t.equal(arms[i]._age, 0.0, "rendering cannot advance acceleration or collision checks")
	t.equal(Array(scene.ctx.scores), scores, "presentation cannot award points")
	t.equal(Array(scene.ctx.alive), alive, "presentation cannot eliminate players")
	packet.world.angles = [0.25, -0.5, 0.75]
	packet.round = 1
	t.ok(replica.accept(packet, 4, "sweeper_storm"), "new round angles accepted")
	replica.render(scene, 0.016)
	for i in arms.size():
		t.ok(is_equal_approx(arms[i].rotation.y, float(packet.world.angles[i])), "new round replaces previous angles")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
