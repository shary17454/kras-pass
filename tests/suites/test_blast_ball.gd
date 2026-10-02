extends RefCounted

class ContactProbe extends GameBall:
	var checks := 0
	func _check_contacts() -> void:
		checks += 1


func run(t: TestHarness, host: Node) -> void:
	t.suite("blast ball lifecycle")
	var ball := GameBall.new()
	host.add_child(ball)
	ball.configure(Color.RED, 0.62, false, true)
	ball.fuse_max = 0.1
	ball.launch(Vector3(0, 0.9, 0), Vector3.RIGHT, 7)
	var events := [0]
	ball.exploded.connect(func(_ball, _position): events[0] += 1)
	ball.tick(0.2)
	ball.tick(0.2)
	t.equal(events[0], 1, "one explosion per launch even without a rearming listener")
	ball.launch(Vector3(0, 0.9, 0), Vector3.RIGHT, 7)
	t.equal(ball._label.text, "0.1", "launch immediately restores visible fuse")
	ball.tick(0.2)
	t.equal(events[0], 2, "rearmed ball can explode again")
	ball.queue_free()
	await host.get_tree().process_frame
	var probe := ContactProbe.new()
	host.add_child(probe)
	probe.explosive = true
	probe.fuse_max = 0.1
	probe.launch(Vector3(0, 0.9, 0), Vector3.RIGHT, 7)
	probe.exploded.connect(func(_ball, _position): probe.launch(Vector3(4, 0.9, 0), Vector3.FORWARD, 7))
	probe.tick(0.2)
	t.equal(probe.checks, 0, "rearming listener cannot apply stale overlap contacts to new ball")
	t.ok(not probe.detonated, "listener rearm clears detonation latch")
	probe.tick(0.01)
	t.equal(probe.checks, 1, "new launch checks contacts on its next tick")
	probe.queue_free()
	await host.get_tree().process_frame
	var cfg := MatchConfig.build("blast_ball", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 104)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	var baseline := Balance.num("tuning", "ball.explosive_fuse", 5.0)
	game.on_sudden_death()
	game.ball.fuse = 0.2
	game.ball.last_toucher = 2
	game.ball._touch_cooldown[2] = 0.25
	game.ball.global_position = Vector3(3, 0.9, 2)
	var generation: int = game.ball.launch_generation
	game.on_round_start()
	t.near(game._fuse_max, baseline, 0.0001, "new round removes sudden death fuse override")
	t.near(game.ball.fuse, baseline, 0.0001, "new round has a complete fuse")
	t.equal(game.ball.last_toucher, -1, "new round has no previous attacker credit")
	t.ok(game.ball._touch_cooldown.is_empty(), "new round clears contact cooldowns")
	t.ok(game.ball.launch_generation > generation, "new round is a new launch generation")
	t.ok(game.ball.global_position.is_equal_approx(scene.arena.global_position + Vector3(0, 0.9, 0)), "new round returns ball to centre")
	for slot in scene.ctx.player_count():
		scene.ctx.alive[slot] = slot == 0
	scene.ctx.fighter(0).global_position = Vector3(0, 0.9, -100)
	var headings: Array[Vector3] = []
	for fps in [30, 60, 120]:
		game.ball.launch(Vector3(0, 0.9, 0), Vector3.RIGHT, 7)
		for tick in fps / 2:
			game.ball.global_position = Vector3(0, 0.9, 0)
			game.tick(1.0 / fps)
		headings.append(game.ball.velocity.normalized())
	t.ok(headings[0].angle_to(headings[1]) < 0.03, "homing strength remains comparable at 30 and 60 Hz")
	t.ok(headings[2].angle_to(headings[1]) < 0.03, "homing strength remains comparable at 60 and 120 Hz")
	var adapter = load("res://src/net/blast_replica.gd").new()
	var world: Dictionary = JSON.parse_string(JSON.stringify(adapter.capture(game)))
	t.ok(adapter.valid(world), "blast world survives JSON")
	for field in world:
		var missing := world.duplicate(true)
		missing.erase(field)
		t.ok(not adapter.valid(missing), "blast world requires " + field)
	for field in ["position", "velocity", "explosion_position"]:
		for value in [null, [], [0, 0], [0, 0, 0, 0], [NAN, 0, 0], [true, 0, 0], [10001, 0, 0]]:
			var bad := world.duplicate(true)
			bad[field] = value
			t.ok(not adapter.valid(bad), "reject malformed blast vector")
	for field in ["generation", "explosion_sequence", "fuse", "fuse_max"]:
		for value in [null, true, "1", NAN, INF, -1, 1000001]:
			var bad := world.duplicate(true)
			bad[field] = value
			t.ok(not adapter.valid(bad), "reject malformed blast scalar")
	var scores := Array(scene.ctx.scores)
	var living: Variant = scene.ctx.alive.duplicate()
	world.explosion_sequence = 5
	world.fuse = 1.2
	world.position = [2, 0.9, 3]
	AudioManager._last_played.erase("explode")
	adapter.render(game, world, 0.1, true, true)
	t.ok(not AudioManager._last_played.has("explode"), "first snapshot does not play historical explosion")
	for repeat in 10:
		adapter.render(game, world, 1.0, false, true)
	t.near(game.ball.fuse, 1.2, 0.0001, "presentation never advances fuse")
	t.equal(game.ball._label.text, "1.2", "replica displays host fuse")
	t.equal(game.ball.collision_mask, 0, "replica cannot detect gameplay contacts")
	t.equal(Array(scene.ctx.scores), scores, "replica cannot score")
	t.equal(scene.ctx.alive, living, "replica cannot eliminate")
	world.explosion_sequence += 1
	adapter.render(game, world, 0.1, false, true)
	if AudioManager.enabled:
		t.ok(AudioManager._last_played.has("explode"), "fresh explosion plays feedback")
	AudioManager._last_played.erase("explode")
	adapter.render(game, world, 0.1, false, true)
	t.ok(not AudioManager._last_played.has("explode"), "duplicate does not replay explosion")
	world.explosion_sequence += 1
	adapter.render(game, world, 0.1, true, false)
	adapter.render(game, world, 0.1, false, true)
	t.ok(not AudioManager._last_played.has("explode"), "suppressed reconnect event stays consumed")
	world.detonated = true
	world.fuse = 0
	t.ok(adapter.valid(world), "terminal detonation is valid")
	adapter.render(game, world, 0.1, false, true)
	t.ok(not game.ball.visible, "terminal detonated ball is hidden")
	world.detonated = false
	world.fuse = 2.0
	world.generation += 1
	world.position = [-2, 0.9, -3]
	adapter.render(game, world, 0.001, false, false)
	t.ok(game.ball.visible, "new launch restores visibility")
	t.ok(game.ball.global_position.is_equal_approx(Vector3(-2, 0.9, -3)), "new launch snaps without interpolating across arena")
	var replica = load("res://src/net/match_replica.gd").new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	packet.phase = MatchPhase.P.PLAYING
	packet.time = 30
	t.ok(replica.accept(packet, 4, "blast_ball"), "shared match accepts blast world")
	var invalid := packet.duplicate(true)
	invalid.world.erase("fuse")
	t.ok(not replica.accept(invalid, 4, "blast_ball"), "shared match rejects incomplete blast world")
	t.equal(replica.target, packet, "invalid blast packet preserves last state")
	AudioManager._last_played.erase("explode")
	replica.render(scene, 0.1)
	t.ok(not AudioManager._last_played.has("explode"), "shared first snapshot is silent")
	packet.world.explosion_sequence += 1
	t.ok(replica.accept(packet, 4, "blast_ball"), "shared match accepts fresh explosion")
	replica.render(scene, 0.1)
	if AudioManager.enabled:
		t.ok(AudioManager._last_played.has("explode"), "shared fresh explosion plays sound")
	AudioManager._last_played.erase("explode")
	packet.world.explosion_sequence += 1
	t.ok(replica.accept(packet, 4, "blast_ball"), "shared match accepts reconnect snapshot")
	replica._event_received_at = replica.received_at - 1501
	replica.render(scene, 0.1)
	t.ok(not AudioManager._last_played.has("explode"), "shared reconnect skips historical explosion")
	packet.round += 1
	packet.world.explosion_sequence += 1
	t.ok(replica.accept(packet, 4, "blast_ball"), "shared match accepts next round")
	replica.render(scene, 0.1)
	t.ok(not AudioManager._last_played.has("explode"), "round transition does not replay explosion")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
