extends RefCounted

const Replica = preload("res://src/net/match_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("fawda bomb presentation")
	var enabled: bool = AudioManager.enabled
	AudioManager.enabled = false
	var source := _scene(host)
	var guest := _scene(host)
	var game: Node = source.controller
	await _pickup_arbitration(t, source)
	game._drop_bomb()
	var bomb: Dictionary = game._bombs[0]
	t.equal(bomb.id, 1, "actual drop assigns stable round-local identity")
	t.equal(game.bomb_events.drop.sequence, 1, "actual drop records its feedback")
	for slot in 4: source.ctx.fighter(slot).global_position = Vector3(30 + slot * 10, 1, 30)
	var rider: Fighter = source.ctx.fighter(0)
	rider.global_position = bomb.node.global_position
	game._try_pickup(bomb, bomb.node)
	game._tick_bombs(0.01)
	t.equal(rider.carrying, 1, "actual pickup sets carrying state")
	t.equal(bomb.held, 0, "actual pickup binds the bomb to its holder")
	var replica = Replica.new()
	var packet := _packet(replica, source)
	t.ok(replica.accept(packet, 4, "fawda"), "actual held bomb survives JSON serialization")
	for key in packet.world.keys():
		var bad := packet.duplicate(true)
		bad.world.erase(key)
		t.ok(not replica.accept(bad, 4, "fawda"), "missing world field rejected")
	for key in packet.world.bombs[0].keys():
		var bad := packet.duplicate(true)
		bad.world.bombs[0].erase(key)
		t.ok(not replica.accept(bad, 4, "fawda"), "missing bomb field rejected")
	for field in ["id", "fuse", "held", "thrower"]:
		for value in [-2, INF, NAN, true, "1", 1000001]:
			var bad := packet.duplicate(true)
			bad.world.bombs[0][field] = value
			t.ok(not replica.accept(bad, 4, "fawda"), "invalid bomb scalar rejected")
	for field in ["position", "velocity"]:
		for value in [INF, NAN, 10001, true, "1"]:
			var bad := packet.duplicate(true)
			bad.world.bombs[0][field][0] = value
			t.ok(not replica.accept(bad, 4, "fawda"), "invalid bomb vector rejected")
	var bad := packet.duplicate(true)
	bad.world.bombs.append(bad.world.bombs[0].duplicate(true))
	t.ok(not replica.accept(bad, 4, "fawda"), "duplicate bomb identity rejected")
	bad.world.bombs[1].id = 2
	t.ok(not replica.accept(bad, 4, "fawda"), "two bombs cannot bind the same holder")
	bad = packet.duplicate(true)
	bad.world.bombs[0].held = 4
	t.ok(not replica.accept(bad, 4, "fawda"), "holder must belong to roster")
	bad = packet.duplicate(true)
	bad.world.bombs[0].fuse = 5.01
	t.ok(not replica.accept(bad, 4, "fawda"), "fuse cannot exceed authored lifetime")
	for value in [-1, 2, 0.5, INF, NAN, true, "1"]:
		bad = packet.duplicate(true)
		bad.world.carrying[0] = value
		t.ok(not replica.accept(bad, 4, "fawda"), "invalid carrying flag rejected")
	bad = packet.duplicate(true)
	bad.world.bombs[0].id = 0
	t.ok(not replica.accept(bad, 4, "fawda"), "zero bomb identity rejected")
	bad = packet.duplicate(true)
	bad.world.bombs[0].extra = 1
	t.ok(not replica.accept(bad, 4, "fawda"), "extra bomb field rejected")
	for kind in packet.world.events:
		var invalid := packet.duplicate(true)
		invalid.world.events.erase(kind)
		t.ok(not replica.accept(invalid, 4, "fawda"), "every feedback kind required")
		for value in [-1, 0.5, 1000001, INF, NAN, true, "1"]:
			invalid = packet.duplicate(true)
			invalid.world.events[kind].sequence = value
			t.ok(not replica.accept(invalid, 4, "fawda"), "invalid event generation rejected")
		invalid = packet.duplicate(true)
		invalid.world.events[kind].position = [0, INF, 0]
		t.ok(not replica.accept(invalid, 4, "fawda"), "invalid event position rejected")
	for count in [1, 2, 3, 5]: t.ok(not replica.accept(packet, count, "fawda"), "wrong roster rejected")
	AudioManager.enabled = true
	replica._last_phase = MatchPhase.P.PLAYING
	replica._last_round = int(packet.round)
	var voice: int = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "baseline does not replay drop or pickup")
	t.equal(guest.ctx.fighter(0).carrying, 1, "guest renders host carrying state")
	t.equal(guest.controller.hud_value(0), "✸", "existing HUD reflects held bomb")
	t.ok(guest.controller._bombs.is_empty(), "guest has no live rule bombs")
	t.equal(replica._fawda.views.size(), 1, "one host bomb creates one presentation")
	var view: Dictionary = replica._fawda.views[1]
	t.ok(not view.node is CollisionObject3D, "guest bomb has no collision body")
	t.near(view.wick.scale.y, float(packet.world.bombs[0].fuse) / 5.0, 0.001, "wick matches host fuse")
	var scores: Array = Array(guest.ctx.scores).duplicate()
	var damage: float = guest.ctx.fighter(0).damage_percent
	var timer: float = guest.controller._drop_timer
	for frame in 30: replica.render(guest, 0.016)
	t.equal(guest.controller._drop_timer, timer, "render does not advance drop timing")
	t.equal(Array(guest.ctx.scores), scores, "render does not award points")
	AudioManager.enabled = false
	var frame := InputRouter.frame(0)
	var saved_bits: int = frame.bits
	var saved_prev: int = frame.prev_bits
	frame.bits = InputFrame.Btn.ATTACK
	frame.prev_bits = 0
	game._read_throws()
	frame.bits = saved_bits
	frame.prev_bits = saved_prev
	t.equal(bomb.held, -1, "real attack input releases held bomb")
	t.near(bomb.vel.length(), 17.0, 0.001, "real throw retains authored speed")
	packet = _packet(replica, source)
	AudioManager.enabled = true
	AudioManager._last_played.erase("swing")
	voice = AudioManager._next_voice
	t.ok(replica.accept(packet, 4, "fawda"), "real thrown state accepted")
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, (voice + 1) % AudioManager.SFX_VOICES, "fresh throw plays once")
	t.equal(guest.ctx.fighter(0).carrying, 0, "guest releases carried state from host")
	AudioManager.enabled = false
	game._tick_bombs(0.1)
	packet = _packet(replica, source)
	t.ok(replica.accept(packet, 4, "fawda"), "actual in-flight trajectory accepted")
	replica.render(guest, 0.016)
	view = replica._fawda.views[1]
	t.ok(view.node.global_position.is_equal_approx(bomb.node.global_position), "guest bomb follows actual host trajectory")
	t.near(view.wick.scale.y, float(bomb.fuse) / 5.0, 0.001, "in-flight wick follows host fuse without ticking locally")
	game._detonate(0)
	packet = _packet(replica, source)
	AudioManager.enabled = true
	AudioManager._last_played.erase("explode")
	voice = AudioManager._next_voice
	t.ok(replica.accept(packet, 4, "fawda"), "real terminal explosion accepted")
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, (voice + 1) % AudioManager.SFX_VOICES, "fresh explosion plays once")
	t.equal(replica._fawda.views.size(), 0, "detonation removes guest bomb presentation")
	t.equal(guest.ctx.fighter(0).damage_percent, damage, "guest explosion never applies blast damage")
	AudioManager._last_played.erase("explode")
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "duplicate cannot replay explosion")
	AudioManager.enabled = false
	game._drop_bomb()
	packet = _packet(replica, source)
	AudioManager.enabled = true
	AudioManager._last_played.erase("tick")
	voice = AudioManager._next_voice
	t.ok(replica.accept(packet, 4, "fawda"), "stale state remains valid for presentation")
	replica._event_received_at = replica.received_at - 1501
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "stale drop is quiet")
	t.equal(replica._fawda.views.size(), 1, "stale baseline still restores visible bomb")
	game.on_round_start()
	game._drop_bomb()
	packet = _packet(replica, source)
	packet.round += 1
	t.ok(replica.accept(packet, 4, "fawda"), "new round may reuse identity after baseline reset")
	AudioManager._last_played.erase("go")
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, (voice + 1) % AudioManager.SFX_VOICES, "new round plays only its UI go cue, not old bomb events")
	t.equal(replica._fawda.views.size(), 1, "round reset replaces old presentation without duplicates")
	source.teardown()
	guest.teardown()
	source.queue_free()
	guest.queue_free()
	AudioManager.enabled = enabled
	await host.get_tree().process_frame


func _pickup_arbitration(t: TestHarness, scene: Node) -> void:
	var game: Node = scene.controller
	var saved_rng: int = scene.ctx.rng.state
	var positions: Array[Vector3] = []
	for fighter in scene.ctx.fighters:
		positions.append(fighter.global_position)
	game._drop_bomb()
	var bomb: Dictionary = game._bombs[0]
	for slot in 4:
		scene.ctx.fighter(slot).global_position = bomb.node.global_position + Vector3(30 + slot, 0, 0)
	var first: Fighter = scene.ctx.fighter(0)
	var closer: Fighter = scene.ctx.fighter(1)
	first.global_position = bomb.node.global_position + Vector3(1.5, 0, 0)
	closer.global_position = bomb.node.global_position + Vector3(0.1, 0, 0)
	var rng_state: int = scene.ctx.rng.state
	game._try_pickup(bomb, bomb.node)
	t.equal(bomb.held, 1, "closer bomb collector wins even when a lower slot is in pickup range")
	t.equal(scene.ctx.rng.state, rng_state, "unique nearest bomb collector does not consume tie randomness")
	game._clear_bombs()
	for condition in ["dead", "carrying", "fast"]:
		game._drop_bomb()
		bomb = game._bombs[0]
		for slot in 4:
			scene.ctx.fighter(slot).global_position = bomb.node.global_position + Vector3(30 + slot, 0, 0)
		first.global_position = bomb.node.global_position + Vector3(1.5, 0, 0)
		closer.global_position = bomb.node.global_position + Vector3(0.1, 0, 0)
		if condition == "dead":
			scene.ctx.eliminate(closer.slot)
		closer.carrying = 1 if condition == "carrying" else 0
		if condition == "fast":
			bomb.vel = Vector3(2.1, 0, 0)
		game._try_pickup(bomb, bomb.node)
		t.equal(int(bomb.held), -1 if condition == "fast" else 0, "ineligible nearest player or fast bomb preserves pickup rules: " + condition)
		if condition == "dead":
			scene.ctx.revive(closer.slot)
			closer.respawn_at(closer.global_position)
			closer.set_physics_process(false)
		game._clear_bombs()
	var counts := [0, 0, 0, 0]
	scene.ctx.rng.seed = 88419
	var sequence: Array[int] = []
	for sample in 256:
		game._drop_bomb()
		bomb = game._bombs[0]
		for fighter in scene.ctx.fighters:
			fighter.global_position = bomb.node.global_position + Vector3(0.5, 0, 0)
		game._try_pickup(bomb, bomb.node)
		sequence.append(int(bomb.held))
		counts[int(bomb.held)] += 1
		game._clear_bombs()
		if sample % 16 == 0:
			await scene.get_tree().process_frame
	for slot in 4:
		t.ok(counts[slot] >= 35 and counts[slot] <= 95, "seeded tied bomb pickups give every slot opportunities")
	scene.ctx.fighters.reverse()
	scene.ctx.rng.seed = 88419
	for sample in 32:
		game._drop_bomb()
		bomb = game._bombs[0]
		for fighter in scene.ctx.fighters:
			fighter.global_position = bomb.node.global_position + Vector3(0.5, 0, 0)
		game._try_pickup(bomb, bomb.node)
		t.equal(int(bomb.held), sequence[sample], "same gameplay seed reproduces tied bomb collector despite reversed player order")
		game._clear_bombs()
	scene.ctx.fighters.reverse()
	game._reset_feedback()
	scene.ctx.rng.state = saved_rng
	for slot in 4:
		scene.ctx.fighter(slot).global_position = positions[slot]
	await scene.get_tree().process_frame


func _scene(host: Node) -> Node:
	var cfg := MatchConfig.build("fawda", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 117)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	for f in scene.ctx.fighters: f.set_physics_process(false)
	return scene


func _packet(replica: RefCounted, scene: Node) -> Dictionary:
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	packet.phase = MatchPhase.P.PLAYING
	return packet
