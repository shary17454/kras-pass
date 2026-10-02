extends RefCounted

const Replica = preload("res://src/net/match_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("tide network presentation")
	var cfg := MatchConfig.build("rising_tide", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 117)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var water = scene.arena._water
	water.tick(12.0)
	var replica = Replica.new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	t.ok(replica.accept(packet, 4, "rising_tide"), "serialized tide accepted")
	for field in ["level", "age"]:
		var bad := packet.duplicate(true)
		bad.world.erase(field)
		t.ok(not replica.accept(bad, 4, "rising_tide"), "missing field rejected")
	for level in [-1001, 1001, NAN, INF, "2.5", true]:
		var bad := packet.duplicate(true)
		bad.world.level = level
		t.ok(not replica.accept(bad, 4, "rising_tide"), "invalid level rejected")
	for age in [-1, 3601, NAN, INF, "12", true]:
		var bad := packet.duplicate(true)
		bad.world.age = age
		t.ok(not replica.accept(bad, 4, "rising_tide"), "invalid age rejected")
	var bad := packet.duplicate(true)
	bad.world.extra = 1
	t.ok(not replica.accept(bad, 4, "rising_tide"), "unknown field rejected")
	var scores: Array = Array(scene.ctx.scores)
	var alive: Array = Array(scene.ctx.alive)
	scene.controller.on_round_start()
	replica.render(scene, 0.016)
	t.ok(is_equal_approx(water.level, float(packet.world.level)), "host level restored")
	t.ok(is_equal_approx(water.position.y, float(packet.world.level)), "water plane follows host")
	t.ok(is_equal_approx(water._mesh.position.y, sin(24.0) * 0.08), "wave phase follows host")
	t.equal(water._age, 12.0, "host age restored")
	for frame in 10:
		replica.render(scene, 0.016)
	t.equal(water._age, 12.0, "rendering cannot advance hazard simulation")
	t.equal(Array(scene.ctx.scores), scores, "rendering cannot award points")
	t.equal(Array(scene.ctx.alive), alive, "rendering cannot eliminate players")
	t.ok(water._hit.is_empty(), "rendering never performs submersion checks")
	packet.world = {"level": -6.0, "age": 0.0}
	packet.round = 1
	t.ok(replica.accept(packet, 4, "rising_tide"), "round reset accepted")
	replica.render(scene, 0.016)
	t.equal(water.level, -6.0, "new round clears water level")
	t.equal(water._mesh.position.y, 0.0, "new round clears wave offset")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
