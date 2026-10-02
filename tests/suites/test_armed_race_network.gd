extends RefCounted

const Replica = preload("res://src/net/match_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("armed race network presentation")
	var enabled: bool = AudioManager.enabled
	AudioManager.enabled = false
	var source := _scene(host)
	var guest := _scene(host)
	var game: Node = source.controller
	for slot in 4: source.ctx.fighter(slot).global_position = Vector3(100 + slot * 10, 1, 100)
	source.ctx.fighter(0).global_position = game._crates[0].pos
	game._tick_crates(0.01)
	t.ok(game.held[0] != game.Item.NONE, "real host crate awards a weapon")
	game._drop_bomb(1, source.ctx.fighter(1))
	game._launch_missile(2, source.ctx.fighter(2))
	game.shielded[3] = 2.0
	var replica = Replica.new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(source)))
	packet.phase = MatchPhase.P.PLAYING
	var fixture := FileAccess.open(SaveSystem.storage_root.path_join("armed-world.json"), FileAccess.WRITE)
	t.ok(fixture != null, "captured weapon world saved for server contract verification")
	if fixture != null:
		fixture.store_string(JSON.stringify(packet.world))
		fixture.close()
	t.ok(replica.accept(packet, 4, "sabaq_sawarikh", source.config.arena_id, game._checkpoints.size()), "real host weapons survive JSON snapshot")
	for field in packet.world.keys():
		var bad := packet.duplicate(true)
		bad.world.erase(field)
		t.ok(not replica.accept(bad, 4, "sabaq_sawarikh"), "missing armed race field rejected")
	for value in [-1, 5, 0.5, true, "1", INF, NAN]:
		var bad := packet.duplicate(true)
		bad.world.held[0] = value
		t.ok(not replica.accept(bad, 4, "sabaq_sawarikh"), "invalid inventory rejected")
	for field in ["shields", "held"]:
		var bad := packet.duplicate(true)
		bad.world[field].pop_back()
		t.ok(not replica.accept(bad, 4, "sabaq_sawarikh"), "weapon roster mismatch rejected")
	for value in [-0.01, 6.01, true, "1", INF, NAN]:
		var bad := packet.duplicate(true)
		bad.world.shields[0] = value
		t.ok(not replica.accept(bad, 4, "sabaq_sawarikh"), "invalid shield duration rejected")
	for field in ["life", "arm", "owner"]:
		for value in [true, "1", INF, NAN, 1000000]:
			var bad := packet.duplicate(true)
			bad.world.bombs[0][field] = value
			t.ok(not replica.accept(bad, 4, "sabaq_sawarikh"), "invalid bomb state rejected")
	var bad := packet.duplicate(true)
	bad.world.bombs.append(bad.world.bombs[0].duplicate(true))
	t.ok(not replica.accept(bad, 4, "sabaq_sawarikh"), "duplicate bomb identity rejected")
	bad = packet.duplicate(true)
	bad.world.crates.pop_back()
	t.ok(not replica.accept(bad, 4, "sabaq_sawarikh"), "missing course crate rejected")
	bad = packet.duplicate(true)
	bad.world.shots[0].direction = [0, 0, 0]
	t.ok(not replica.accept(bad, 4, "sabaq_sawarikh"), "zero missile heading rejected")
	bad = packet.duplicate(true)
	bad.world.bombs[0].life = 0.0
	t.ok(not replica.accept(bad, 4, "sabaq_sawarikh"), "expired bomb cannot remain in authoritative world")
	bad = packet.duplicate(true)
	bad.world.crates[0].cooldown = 7.01
	t.ok(not replica.accept(bad, 4, "sabaq_sawarikh"), "crate recharge bound matches authored seven seconds")
	t.ok(replica.accept(packet, 4, "sabaq_sawarikh"), "valid packet still accepted after malformed updates")
	replica.render(guest, 0.016)
	t.equal(Array(guest.controller.held), Array(game.held), "host weapon inventory drives guest HUD")
	t.near(guest.controller.shielded[3], 2.0, 0.001, "guest shield remains host-owned")
	t.equal(replica._armed_race.bombs.size(), 1, "one host bomb creates one visual")
	t.equal(replica._armed_race.projectiles.shots.size(), 1, "one host missile creates one visual")
	t.ok(guest.controller._bombs.is_empty() and guest.controller._missiles.is_empty(), "guest has no weapon physics or fuse simulation")
	for view in replica._armed_race.bombs.values(): t.ok(not view is CollisionObject3D, "bomb view cannot collide or deal damage")
	for view in replica._armed_race.projectiles.shots.values(): t.ok(not view is CollisionObject3D, "missile view cannot collide or deal damage")
	var scores: Array = Array(guest.ctx.scores).duplicate()
	var cooldown: float = guest.controller._crates[0].cooldown
	for frame in 30: replica.render(guest, 0.016)
	t.equal(Array(guest.ctx.scores), scores, "repeated render cannot award race points")
	t.near(guest.controller.shielded[3], 2.0, 0.001, "repeated render cannot expire host shield")
	t.near(guest.controller._crates[0].cooldown, cooldown, 0.001, "repeated render cannot respawn host crate")
	t.equal(replica._armed_race.bombs.size(), 1, "repeated snapshot cannot duplicate bomb")
	t.equal(replica._armed_race.projectiles.shots.size(), 1, "repeated snapshot cannot duplicate missile")
	var position: Vector3 = guest.ctx.fighter(0).global_position
	bad = packet.duplicate(true)
	bad.world.race.checkpoints += 1
	bad.fighters[0].position = [321, 2, 123]
	t.ok(replica.accept(bad, 4, "sabaq_sawarikh"), "unbound caller can validate schema independently of course geometry")
	replica.render(guest, 0.016)
	t.ok(guest.ctx.fighter(0).global_position.is_equal_approx(position), "wrong course cannot mutate fighter presentation")
	t.ok(not replica.accept(bad, 4, "sabaq_sawarikh", source.config.arena_id, game._checkpoints.size()), "course-bound caller rejects incompatible checkpoints")
	game.on_round_start()
	packet = JSON.parse_string(JSON.stringify(replica.capture(source)))
	packet.phase = MatchPhase.P.PLAYING
	packet.round += 1
	t.ok(replica.accept(packet, 4, "sabaq_sawarikh"), "host round reset accepted")
	replica.render(guest, 0.016)
	t.equal(replica._armed_race.bombs.size(), 0, "new round removes previous bomb")
	t.equal(replica._armed_race.projectiles.shots.size(), 0, "new round removes previous missile")
	t.ok(guest.controller.held.all(func(value): return value == 0), "new round restores empty inventory")
	source.teardown()
	guest.teardown()
	source.queue_free()
	guest.queue_free()
	AudioManager.enabled = enabled
	await host.get_tree().process_frame


func _scene(host: Node) -> Node:
	var cfg := MatchConfig.build("sabaq_sawarikh", ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 121)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	for fighter in scene.ctx.fighters: fighter.set_physics_process(false)
	return scene
