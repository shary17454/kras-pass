extends RefCounted

const Replica = preload("res://src/net/match_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	await _crate_claims(t, host)
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
	t.equal(game.weapon_events.pickup.sequence, 1, "actual crate pickup advances host audio generation")
	t.equal(game.weapon_events.drop.sequence, 1, "actual bomb placement advances host audio generation")
	var replica = Replica.new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(source)))
	packet.phase = MatchPhase.P.PLAYING
	var fixture := FileAccess.open(SaveSystem.storage_root.path_join("armed-world.json"), FileAccess.WRITE)
	t.ok(fixture != null, "captured weapon world saved for server contract verification")
	if fixture != null:
		fixture.store_string(JSON.stringify(packet.world))
		fixture.close()
	t.ok(replica.accept(packet, 4, "sabaq_sawarikh", source.config.arena_id, game._checkpoints.size()), "real host weapons survive JSON snapshot")
	for kind in game.WEAPON_EVENTS:
		for value in [-1, 0.5, true, "1", INF, NAN, 1000001]:
			var malformed := packet.duplicate(true)
			malformed.world.events[kind].sequence = value
			t.ok(not replica.accept(malformed, 4, "sabaq_sawarikh"), "invalid weapon event generation rejected")
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
	replica._last_phase = MatchPhase.P.PLAYING
	replica._last_round = int(packet.round)
	AudioManager.enabled = true
	var voice: int = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "first snapshot cannot replay old pickup or bomb placement")
	AudioManager.enabled = false
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
	await _events(t, source, guest, replica)
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
	AudioManager.enabled = true
	AudioManager._last_played.erase("go")
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, (voice + 1) % AudioManager.SFX_VOICES, "new round plays only UI countdown cue, not past weapons")
	AudioManager.enabled = false
	t.equal(replica._armed_race.bombs.size(), 0, "new round removes previous bomb")
	t.equal(replica._armed_race.projectiles.shots.size(), 0, "new round removes previous missile")
	t.ok(guest.controller.held.all(func(value): return value == 0), "new round restores empty inventory")
	source.teardown()
	guest.teardown()
	source.queue_free()
	guest.queue_free()
	AudioManager.enabled = enabled
	await host.get_tree().process_frame


func _crate_claims(t: TestHarness, host: Node) -> void:
	t.suite("armed race simultaneous crate claims")
	var enabled: bool = AudioManager.enabled
	AudioManager.enabled = false
	var scene := _scene(host)
	var game: Node = scene.controller
	var position: Vector3 = game._crates[0].pos
	for nearest in 4:
		_reset_claim(game)
		for slot in 4:
			scene.ctx.fighter(slot).global_position = position + Vector3.RIGHT * (0.1 if slot == nearest else 1.8)
		var expected := RandomNumberGenerator.new()
		expected.state = scene.ctx.rng.state
		expected.randi_range(0, 5)
		var sequence: int = game.weapon_events.pickup.sequence
		game._tick_crates(0.01)
		t.ok(game.held[nearest] != game.Item.NONE, "closest eligible racer wins regardless of seat")
		t.equal(game.held.filter(func(item): return item != game.Item.NONE).size(), 1, "one crate awards exactly one weapon")
		t.equal(game.weapon_events.pickup.sequence, sequence + 1, "one pickup emits one authoritative event")
		t.equal(scene.ctx.rng.state, expected.state, "unique nearest claim consumes only the existing item roll")
	var wins := [0, 0, 0, 0]
	for seed_value in range(64):
		var first := -1
		for repeat in 2:
			_reset_claim(game)
			scene.ctx.rng.seed = 42000 + seed_value
			for slot in 4:
				scene.ctx.fighter(slot).global_position = position
			game._tick_crates(0.01)
			var winner: int = game.held.find_custom(func(item): return item != game.Item.NONE)
			t.ok(winner >= 0, "equal-distance claim still awards an item")
			t.equal(game.held.filter(func(item): return item != game.Item.NONE).size(), 1, "equal-distance claim cannot duplicate inventory")
			if repeat == 0:
				first = winner
				if winner >= 0:
					wins[winner] += 1
			else:
				t.equal(winner, first, "same seed resolves simultaneous claim deterministically")
	for slot in 4:
		t.greater(wins[slot], 0, "fixed seed set does not reserve tied pickups for any seat")
	_reset_claim(game)
	for slot in 4:
		scene.ctx.fighter(slot).global_position = position + Vector3.RIGHT * (0.1 if slot == 0 else 1.0)
	game.held[0] = game.Item.SHIELD
	game.finish_times[1] = 1.0
	game._tick_crates(0.01)
	t.equal(game.held[0], game.Item.SHIELD, "occupied inventory remains unchanged")
	t.equal(game.held[1], game.Item.NONE, "finished racer cannot steal a crate")
	t.ok(game.held[2] != game.Item.NONE or game.held[3] != game.Item.NONE, "eligible remaining racer receives the crate")
	scene.teardown()
	scene.queue_free()
	AudioManager.enabled = enabled
	await host.get_tree().process_frame


func _reset_claim(game: Node) -> void:
	game.held.fill(game.Item.NONE)
	game.finish_times.fill(game.UNFINISHED)
	for crate in game._crates:
		crate.cooldown = 999.0
	game._crates[0].cooldown = 0.0
	game._crates[0].node.show()


func _events(t: TestHarness, source: Node, guest: Node, replica: RefCounted) -> void:
	var game: Node = source.controller
	var fighter: Fighter = source.ctx.fighter(0)
	for kind in ["pickup", "boost", "shield", "block", "hit", "drop", "explode", "respawn"]:
		AudioManager.enabled = false
		match kind:
			"pickup":
				game.held[0] = game.Item.NONE
				fighter.global_position = game._crates[1].pos
				game._tick_crates(0.01)
			"boost":
				game.held[0] = game.Item.BOOST
				game._use(0, fighter)
			"shield":
				game.held[0] = game.Item.SHIELD
				game._use(0, fighter)
			"block", "hit": game._spin_out(0, 1, Vector3.RIGHT)
			"drop": game._drop_bomb(0, fighter)
			"explode": game._detonate({"pos": Vector3(500, 1, 500)}, 0)
			"respawn":
				game.held.fill(game.Item.SHIELD)
				game._crates[0].cooldown = 0.005
				game._tick_crates(0.01)
		t.ok(game.weapon_events[kind].sequence > 0, "real host action advances " + kind)
		var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(source)))
		packet.phase = MatchPhase.P.PLAYING
		t.ok(replica.accept(packet, 4, "sabaq_sawarikh"), "fresh weapon event accepted")
		var sound: String = {"pickup": "pickup", "boost": "dash", "shield": "pickup", "block": "bounce", "hit": "hit", "drop": "bounce", "explode": "explode", "respawn": "tick"}[kind]
		AudioManager.enabled = true
		AudioManager._last_played.erase(sound)
		var voice: int = AudioManager._next_voice
		var scores: Array = Array(guest.ctx.scores).duplicate()
		var velocity: Vector3 = guest.ctx.fighter(1).velocity
		replica.render(guest, 0.016)
		t.equal(AudioManager._next_voice, (voice + 1) % AudioManager.SFX_VOICES, "fresh " + kind + " plays exactly once")
		t.equal(Array(guest.ctx.scores), scores, "weapon presentation never scores")
		t.equal(guest.ctx.fighter(1).velocity, velocity, "weapon presentation never applies guest impulses")
		AudioManager._last_played.erase(sound)
		voice = AudioManager._next_voice
		replica.render(guest, 0.016)
		t.equal(AudioManager._next_voice, voice, "repeated " + kind + " remains quiet without audio debounce")
	var resumed = Replica.new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(source)))
	packet.phase = MatchPhase.P.PLAYING
	t.ok(resumed.accept(packet, 4, "sabaq_sawarikh"), "reconnect baseline accepts existing weapon history")
	resumed._last_phase = MatchPhase.P.PLAYING
	resumed._last_round = int(packet.round)
	AudioManager._last_played.clear()
	var voice: int = AudioManager._next_voice
	resumed.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "reconnect baseline does not replay old weapon sounds")
	resumed._armed_race.queue_free()
	await guest.get_tree().process_frame
	AudioManager.enabled = false


func _scene(host: Node) -> Node:
	var cfg := MatchConfig.build("sabaq_sawarikh", ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 121)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	for fighter in scene.ctx.fighters: fighter.set_physics_process(false)
	return scene
