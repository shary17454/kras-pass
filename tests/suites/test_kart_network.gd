extends RefCounted

const Replica = preload("res://src/net/match_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("kart network presentation")
	var enabled: bool = AudioManager.enabled
	AudioManager.enabled = false
	var source := _scene(host)
	var guest := _scene(host)
	var game: Node = source.controller
	for slot in 4: source.ctx.fighter(slot).global_position = Vector3(100 + slot * 10, 1, 100)
	var rider: Fighter = source.ctx.fighter(0)
	rider.global_position = game._boost_pads[0].pos + Vector3.UP
	game._check_boost(0, rider, 1.0 / 60.0)
	t.equal(game.boost_serial[0], 1, "real pad contact records one boost generation")
	_finish_checkpoints(game, rider)
	t.equal(game.lap[0], 3, "real controller checkpoint rules record three laps")
	game.on_fighter_fell(1)
	game.process_respawns(0.75)
	t.ok(game.is_recovering(1), "real fall starts the original rescue process")
	var replica = Replica.new()
	var packet := _packet(replica, source)
	t.ok(replica.accept(packet, 4, "kart_sprint", "circuit_loop", game._checkpoints.size()), "finished and rescued racers survive JSON serialization")
	t.ok(not replica.accept(packet, 4, "kart_sprint", "circuit_loop", game._checkpoints.size() + 1), "wrong course geometry rejected before rendering")
	for key in packet.world.keys():
		var bad := packet.duplicate(true)
		bad.world.erase(key)
		t.ok(not replica.accept(bad, 4, "kart_sprint"), "missing race world field rejected")
	for field in ["elapsed", "laps", "checkpoints"]:
		for value in [-1, INF, NAN, true, "1", 1000001]:
			var bad := packet.duplicate(true)
			bad.world[field] = value
			t.ok(not replica.accept(bad, 4, "kart_sprint"), "invalid race scalar rejected")
	for field in ["times", "lap", "next"]:
		for value in [-1, 0.5, INF, NAN, true, "1", 1000000001]:
			var bad := packet.duplicate(true)
			bad.world[field][0] = value
			t.ok(not replica.accept(bad, 4, "kart_sprint"), "invalid progress value rejected")
	for field in ["times", "lap", "next", "started", "recovery"]:
		var bad := packet.duplicate(true)
		bad.world[field].pop_back()
		t.ok(not replica.accept(bad, 4, "kart_sprint"), "wrong per-player field count rejected")
	for value in [-0.5, 1.01, INF, NAN, true, "1"]:
		var bad := packet.duplicate(true)
		bad.world.recovery[1] = value
		t.ok(not replica.accept(bad, 4, "kart_sprint"), "invalid recovery progress rejected")
	var bad := packet.duplicate(true)
	bad.world.recovery[0] = 0.0
	t.ok(not replica.accept(bad, 4, "kart_sprint"), "finished racer cannot be recovering")
	bad = packet.duplicate(true)
	bad.world.lap[0] = 2
	t.ok(not replica.accept(bad, 4, "kart_sprint"), "finished time requires complete laps")
	bad = packet.duplicate(true)
	bad.world.times[0] = int(ceil(packet.world.elapsed * 100.0)) + 1
	t.ok(not replica.accept(bad, 4, "kart_sprint"), "finish cannot precede observed elapsed time")
	bad = packet.duplicate(true)
	bad.world.next[0] = int(packet.world.checkpoints)
	t.ok(not replica.accept(bad, 4, "kart_sprint"), "next checkpoint must belong to course")
	for value in [-1, 0.5, 1000001, INF, NAN, true, "1"]:
		bad = packet.duplicate(true)
		bad.world.boost.serial[0] = value
		t.ok(not replica.accept(bad, 4, "kart_sprint"), "invalid boost generation rejected")
	for value in [-0.1, 2.01, INF, NAN, true, "1"]:
		bad = packet.duplicate(true)
		bad.world.boost.pads[0][0] = value
		t.ok(not replica.accept(bad, 4, "kart_sprint"), "invalid boost recharge rejected")
	for count in [1, 2, 3, 5]: t.ok(not replica.accept(packet, count, "kart_sprint"), "wrong roster rejected")
	bad = packet.duplicate(true)
	bad.world.boost.pads.pop_back()
	t.ok(not replica.accept(bad, 4, "kart_sprint"), "missing course boost pad rejected")
	bad = packet.duplicate(true)
	bad.world.boost.pads[0].pop_back()
	t.ok(not replica.accept(bad, 4, "kart_sprint"), "wrong boost pad roster rejected")
	bad = packet.duplicate(true)
	bad.world.started[0] = 1
	t.ok(not replica.accept(bad, 4, "kart_sprint"), "started flag cannot be a numeric boolean")
	AudioManager.enabled = true
	replica._last_phase = MatchPhase.P.PLAYING
	replica._last_round = int(packet.round)
	var voice: int = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "baseline cannot replay old finish or boost cues")
	t.equal(guest.controller._finished, 1, "host finish count restored")
	t.equal(guest.controller.hud_value(0), "%.2f" % (game.finish_times[0] / 100.0), "existing HUD renders host finish time")
	t.equal(guest.controller.next_checkpoint(0), game.next_checkpoint(0), "host checkpoint index restored")
	t.ok(guest.controller.is_recovering(1), "guest exposes replicated recovery state")
	t.ok(guest.controller._recoveries.is_empty(), "guest has no live rescue rules or respawn callbacks")
	t.equal(replica._kart.rescues.size(), 1, "active host rescue creates one original halo")
	var rescue: Node3D = replica._kart.rescues[1]
	t.ok(not rescue is CollisionObject3D, "rescue effect has no collision body")
	t.ok(rescue.global_position.is_equal_approx(guest.ctx.fighter(1).global_position), "halo follows the replicated rider")
	t.near(guest.controller._boost_pads[0].cooldown[0], game._boost_pads[0].cooldown[0], 0.001, "pad recharge restored without local ticking")
	var elapsed: float = guest.controller._elapsed
	var scores: Array = Array(guest.ctx.scores).duplicate()
	for frame in 30: replica.render(guest, 0.016)
	t.equal(guest.controller._elapsed, elapsed, "render never advances race clock")
	t.equal(Array(guest.ctx.scores), scores, "render never awards race scores")
	t.equal(replica._kart.rescues.size(), 1, "repeated frames do not duplicate halo nodes")
	var position: Vector3 = guest.ctx.fighter(0).global_position
	bad = packet.duplicate(true)
	bad.world.checkpoints += 1
	bad.fighters[0].position = [321.0, 2.0, 123.0]
	t.ok(replica.accept(bad, 4, "kart_sprint"), "standalone caller still applies schema validation")
	replica.render(guest, 0.016)
	t.ok(guest.ctx.fighter(0).global_position.is_equal_approx(position), "course mismatch cannot mutate fighter presentation")
	t.equal(guest.controller._elapsed, elapsed, "course mismatch cannot mutate race clock")
	t.ok(replica.accept(packet, 4, "kart_sprint", "circuit_loop", game._checkpoints.size()), "matching course remains usable after mismatch")
	AudioManager.enabled = false
	for step in game._checkpoints.size() + 1:
		source.ctx.fighter(2).global_position = game.next_checkpoint(2)
		game.tick(1.0 / 60.0)
	source.ctx.fighter(2).global_position = game._boost_pads[1].pos + Vector3.UP
	game._check_boost(2, source.ctx.fighter(2), 1.0 / 60.0)
	packet = _packet(replica, source)
	AudioManager.enabled = true
	AudioManager._last_played.erase("tick")
	AudioManager._last_played.erase("dash")
	voice = AudioManager._next_voice
	t.ok(replica.accept(packet, 4, "kart_sprint"), "new real lap and boost accepted")
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, (voice + 2) % AudioManager.SFX_VOICES, "fresh lap and boost each play once")
	AudioManager._last_played.erase("tick")
	AudioManager._last_played.erase("dash")
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "duplicates remain quiet without relying on audio debounce")
	AudioManager.enabled = false
	game.process_respawns(3.0)
	_finish_checkpoints(game, source.ctx.fighter(2))
	packet = _packet(replica, source)
	packet.phase = MatchPhase.P.FINISH
	AudioManager.enabled = true
	AudioManager._last_played.erase("score")
	replica._last_phase = MatchPhase.P.FINISH
	voice = AudioManager._next_voice
	t.ok(replica.accept(packet, 4, "kart_sprint"), "new finish cue accepted in ending phase")
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, (voice + 1) % AudioManager.SFX_VOICES, "ending snapshot still presents fresh finish cue")
	t.equal(replica._kart.rescues.size(), 0, "completed rescue removes guest halo")
	t.ok(not guest.controller.is_recovering(1), "completed host rescue restores guest status")
	game.on_round_start()
	packet = _packet(replica, source)
	packet.round += 1
	AudioManager._last_played.erase("go")
	voice = AudioManager._next_voice
	t.ok(replica.accept(packet, 4, "kart_sprint"), "reset race state accepted")
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, (voice + 1) % AudioManager.SFX_VOICES, "round reset plays only UI go cue")
	t.equal(guest.controller._finished, 0, "round reset clears finish count")
	t.equal(guest.controller.boost_serial, [0, 0, 0, 0], "round reset clears sampled boost generations")
	AudioManager.enabled = false
	source.ctx.config.rules["party_short_race"] = true
	source.ctx.config.rules["race_laps"] = 1
	game.on_round_start()
	_finish_checkpoints(game, rider)
	packet = _packet(replica, source)
	packet.round += 2
	t.ok(replica.accept(packet, 4, "kart_sprint"), "host short-race rules serialize with completed result")
	replica.render(guest, 0.016)
	t.equal(guest.controller.laps(), 1, "guest uses host short-race lap limit instead of default three")
	t.equal(guest.controller._finished, 1, "short-race completion restored")
	t.equal(guest.controller.hud_value(0), "%.2f" % (game.finish_times[0] / 100.0), "short-race HUD shows host finish time")
	source.teardown()
	guest.teardown()
	source.queue_free()
	guest.queue_free()
	AudioManager.enabled = enabled
	await host.get_tree().process_frame


func _scene(host: Node) -> Node:
	var cfg := MatchConfig.build("kart_sprint", ["fanoos", "mowja", "ramla", "nabta"], 0, 1, 117)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	for f in scene.ctx.fighters: f.set_physics_process(false)
	return scene


func _finish_checkpoints(game: Node, rider: Fighter) -> void:
	# Rule-level controller fixture, not independent physical driving evidence.
	for step in game.laps() * game._checkpoints.size() + 1:
		rider.global_position = game.next_checkpoint(rider.slot)
		game.tick(1.0 / 60.0)


func _packet(replica: RefCounted, scene: Node) -> Dictionary:
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	packet.phase = MatchPhase.P.PLAYING
	return packet
