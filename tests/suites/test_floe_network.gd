extends RefCounted

const Replica = preload("res://src/net/match_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("moving floe network presentation")
	var cfg := MatchConfig.build("drift_floes", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 117)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	for floe in game._floes:
		floe.body.sync_to_physics = false
	game.on_round_start()
	game.tick(12.5)
	var replica = Replica.new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	t.ok(replica.accept(packet, 4, "drift_floes"), "serialized floe world accepted")
	for field in ["age", "positions"]:
		var bad := packet.duplicate(true)
		bad.world.erase(field)
		t.ok(not replica.accept(bad, 4, "drift_floes"), "missing world field rejected")
	for age in [-1, 3601, NAN, INF, "12", true]:
		var bad := packet.duplicate(true)
		bad.world.age = age
		t.ok(not replica.accept(bad, 4, "drift_floes"), "invalid age rejected")
	for position in [[0, 0], [0, 0, 0, 0], null, "bad", [1001, 0, 0], [NAN, 0, 0], [INF, 0, 0], ["1", 0, 0], [true, 0, 0]]:
		var bad := packet.duplicate(true)
		bad.world.positions[0] = position
		t.ok(not replica.accept(bad, 4, "drift_floes"), "invalid platform position rejected")
	for positions in [[], packet.world.positions.slice(0, 2), packet.world.positions + [[0, 0, 0]]]:
		var bad := packet.duplicate(true)
		bad.world.positions = positions
		t.ok(not replica.accept(bad, 4, "drift_floes"), "wrong platform count rejected")
	var bad := packet.duplicate(true)
	bad.world.extra = 1
	t.ok(not replica.accept(bad, 4, "drift_floes"), "extra world field rejected")
	game.on_round_start()
	replica.render(scene, 0.016)
	for index in 3:
		var row: Array = packet.world.positions[index]
		var body: AnimatableBody3D = game._floes[index].body
		t.ok(body.global_position.is_equal_approx(Vector3(row[0], row[1], row[2])), "new round snaps to host platform")
		t.equal(body.collision_layer, 0, "guest platform cannot carry or collide with players")
		t.ok(not body.sync_to_physics, "guest presentation cannot enqueue kinematic movement")
	var scores: Array = Array(scene.ctx.scores).duplicate()
	var speed: float = game._floes[0].speed
	packet.world.positions[0][0] += 1.0
	t.ok(replica.accept(packet, 4, "drift_floes"), "moving platform update accepted")
	var before: Vector3 = game._floes[0].body.global_position
	replica.render(scene, 0.016)
	var after: Vector3 = game._floes[0].body.global_position
	t.ok(after.x > before.x and after.x < before.x + 1.0, "movement interpolates between host snapshots")
	for frame in 30:
		replica.render(scene, 0.016)
	t.ok(absf(game._floes[0].body.global_position.x - before.x - 1.0) < 0.001, "platform converges to host position")
	t.equal(game._time, 12.5, "presentation does not advance motion clock")
	t.equal(game._floes[0].speed, speed, "presentation does not change difficulty")
	t.equal(Array(scene.ctx.scores), scores, "presentation does not award points")
	t.ok(game._respawn_timers.is_empty(), "presentation does not schedule respawns")
	game.on_round_start()
	packet = replica.capture(scene)
	packet.round = 1
	t.ok(replica.accept(packet, 4, "drift_floes"), "reset world accepted")
	replica.render(scene, 0.016)
	t.equal(game._time, 0.0, "new round clears old motion age")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
