extends RefCounted

const View = preload("res://src/net/colossus_replica.gd")
const Replica = preload("res://src/net/match_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("colossus network carved presentation")
	var audio_enabled: bool = AudioManager.enabled
	AudioManager.enabled = true
	var scenes: Array = []
	for peer in 2:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("boss_colossus", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 9614), "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		for fighter in scene.ctx.fighters: fighter.set_physics_process(false)
		scenes.append(scene)
	var source: Node = scenes[0]
	var guest: Node = scenes[1]
	var game: Node = source.controller
	for slot in 4:
		source.ctx.fighter(slot).global_position = Vector3(6, 0, 0) if slot == 0 else Vector3(80 + slot, 0, 0)
	game._slam()
	game._tick_telegraphs(2.0)
	t.equal(game._craters.size(), 1, "actual slam creates host crater")
	t.equal(game.strike_sequence, 1, "actual slam records strike")
	t.ok(not source.arena.is_inside(Vector3(6, 0, 0)), "host ground is carved at fist")
	var fighter: Fighter = source.ctx.fighter(0)
	fighter.global_position = Vector3(9.55, 0, 0)
	fighter._attack_time = 0.2
	game._check_arm_hits()
	fighter._attack_time = 0.0
	t.equal(game.boss_health, 745.0, "actual rim attack damages exposed host arm")
	game.telegraph(Vector3(-4, 0, 2), 3.0, 1.2, func(_pos, _radius): pass)
	var world: Dictionary = JSON.parse_string(JSON.stringify(View.capture(game)))
	var packet: Dictionary = JSON.parse_string(JSON.stringify(Replica.new().capture(source)))
	packet.phase = MatchPhase.P.PLAYING
	var replica := Replica.new()
	var sample_time := {"now": 1000}
	replica.receive_clock = func(): return sample_time.now
	t.equal(packet.world, world, "shared snapshot capture includes actual colossus world")
	t.ok(replica.accept(packet, 4, "boss_colossus"), "shared snapshot validates colossus packet")
	var malformed := packet.duplicate(true)
	malformed.world.exposed = -1
	t.ok(not replica.accept(malformed, 4, "boss_colossus"), "shared snapshot rejects invalid exposure")
	t.equal(replica.target, packet, "invalid world cannot replace accepted snapshot")
	var capture := FileAccess.open(SaveSystem.storage_root.path_join("colossus-world.json"), FileAccess.WRITE)
	t.ok(capture != null, "actual host capture is writable")
	if capture != null:
		capture.store_string(JSON.stringify(world))
		capture.close()
	for count in [2, 3, 4]: t.ok(View.valid(world, count), "actual JSON accepts bounded roster")
	for field in world.keys():
		var bad := world.duplicate(true)
		bad.erase(field)
		t.ok(not View.valid(bad, 4), "missing field rejected: " + field)
	for field in world.boss.keys():
		var invalid := world.duplicate(true)
		invalid.boss.erase(field)
		t.ok(not View.valid(invalid, 4), "missing boss state rejected")
	for entry in [{"key": "health", "values": [-1, 800.1, true, NAN, INF, null]},
		{"key": "phase", "values": [-1, 1, 0.5, true]},
		{"key": "defeated", "values": [true, 0]},
		{"key": "position", "values": [[10001, 0, 0], [NAN, 0, 0], [0, 0]]}]:
		for value in entry.values:
			var invalid := world.duplicate(true)
			invalid.boss[entry.key] = value
			t.ok(not View.valid(invalid, 4), "invalid boss authority state rejected")
	for group in ["warnings", "craters"]:
		for field in world[group][0].keys():
			var invalid := world.duplicate(true)
			invalid[group][0].erase(field)
			t.ok(not View.valid(invalid, 4), "missing object field rejected")
		for id in ["", "01", "-1", "1.0", "1000000000000000000", 1, null]:
			var invalid := world.duplicate(true)
			invalid[group][0].id = id
			t.ok(not View.valid(invalid, 4), "invalid object id rejected")
		var invalid := world.duplicate(true)
		invalid[group].append(invalid[group][0].duplicate(true))
		t.ok(not View.valid(invalid, 4), "duplicate object rejected")
		invalid = world.duplicate(true)
		invalid[group][0].extra = 1
		t.ok(not View.valid(invalid, 4), "extra object field rejected")
		invalid = world.duplicate(true)
		invalid[group] = []
		for index in 65:
			var row: Dictionary = world[group][0].duplicate(true)
			row.id = str(index + 10)
			invalid[group].append(row)
		t.ok(not View.valid(invalid, 4), "object population is bounded")
	for entry in [{"key": "exposed", "values": [-1, 2.41, true, NAN, INF, null]},
		{"key": "fist_scale", "values": [[0, 1, 1], [1.21, 1, 1], [NAN, 1, 1], [1, 1]]},
		{"key": "arm_rotation", "values": [[0, PI + 0.1, 0], [INF, 0, 0]]}]:
		for value in entry.values:
			var bad := world.duplicate(true)
			bad[entry.key] = value
			t.ok(not View.valid(bad, 4), "invalid pose or exposure rejected")
	var bad := world.duplicate(true)
	bad.craters[0].id = bad.warnings[0].id
	t.ok(not View.valid(bad, 4), "cross-type duplicate id rejected")
	for radius in [0.74, 100.1, NAN, true]:
		bad = world.duplicate(true)
		bad.craters[0].radius = radius
		t.ok(not View.valid(bad, 4), "invalid crater radius rejected")
	replica._last_phase = MatchPhase.P.PLAYING
	replica._last_round = 0
	var voice: int = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "initial baseline does not replay historical sounds")
	var view: Node = replica._colossus
	await host.get_tree().physics_frame
	await host.get_tree().physics_frame
	t.ok(guest.controller.presentation_only, "guest controller has presentation authority only")
	t.equal(guest.controller.boss_health, game.boss_health, "guest mirrors host damage")
	t.equal(guest.controller._fist.global_position, game._fist.global_position, "guest mirrors buried fist pose")
	t.equal(guest.controller._arm.rotation, game._arm.rotation, "guest mirrors arm rotation")
	t.ok(guest.arena._crater_floor._body == null, "guest carved floor has no collider")
	t.ok(not guest.arena.is_inside(Vector3(6, 0, 0)), "guest ground query matches real crater")
	t.equal(view.craters.size(), 1, "one presentation rim per host crater")
	t.equal(view.warnings.size(), 1, "one presentation warning per host warning")
	t.empty(guest.controller._craters, "guest has no simulated crater ownership")
	t.empty(guest.controller._telegraphs, "guest has no warning callbacks")
	t.equal(_colliders(view), 0, "network visual nodes never collide")
	var mesh: Mesh = guest.arena._crater_floor._mesh.mesh
	replica.render(guest, 0.016)
	t.equal(guest.arena._crater_floor._mesh.mesh, mesh, "repeated packet does not rebuild carved mesh")
	guest.controller._slam()
	guest.controller._sweep()
	guest.controller._open_crater(Vector3.ZERO, 4.0)
	guest.controller._check_arm_hits()
	guest.controller.boss_think(10.0)
	t.equal(guest.controller.boss_health, 745.0, "guest cannot decide damage")
	t.equal(guest.arena._crater_floor._mesh.mesh, mesh, "guest simulation cannot mutate host ground")
	t.empty(guest.controller._craters, "guest cannot spawn local crater")
	game.damage_boss(1.0, 0)
	packet = _packet(source)
	sample_time.now = 2000
	t.ok(replica.accept(packet, 4, "boss_colossus"), "fresh host damage accepted")
	t.equal(replica.received_at - replica._event_received_at, 1000, "fresh sample at exact feedback boundary")
	AudioManager._last_played.erase("hit")
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, (voice + 1) % AudioManager.SFX_VOICES, "fresh host damage sound plays once")
	t.equal(guest.controller.boss_health, 744.0, "shared path updates fresh host health")
	AudioManager._last_played.erase("hit")
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "duplicate snapshot does not replay hit")
	game.damage_boss(1.0, 0)
	packet = _packet(source)
	sample_time.now = 3001
	t.ok(replica.accept(packet, 4, "boss_colossus"), "stale host state remains accepted")
	AudioManager._last_played.erase("hit")
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "1001 ms sample suppresses historical sound")
	t.equal(guest.controller.boss_health, 743.0, "stale state still updates visible health")
	source.arena.apply_network_radius(12.0)
	packet = _packet(source)
	t.ok(replica.accept(packet, 4, "boss_colossus"), "host radius update accepted with craters")
	replica.render(guest, 0.016)
	t.near(guest.arena._crater_floor.radius, 12.0, 0.001, "shared radius update rebuilds carved guest rim")
	t.ok(not guest.arena.is_inside(Vector3(13, 0, 0)), "guest excludes shrunken outer ground")
	t.ok(not guest.arena.is_inside(Vector3(6, 0, 0)), "radius update preserves existing crater")
	t.ok(guest.arena._crater_floor._body == null, "radius update cannot recreate collision")
	game.damage_boss(215.0, 0)
	packet = _packet(source)
	sample_time.now = 3501
	t.ok(replica.accept(packet, 4, "boss_colossus"), "actual host phase threshold accepted")
	for effect in ["hit", "powerup"]: AudioManager._last_played.erase(effect)
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(guest.controller.phase, 1, "shared path mirrors host phase threshold")
	t.equal(AudioManager._next_voice, (voice + 2) % AudioManager.SFX_VOICES, "fresh damage and phase each play once")
	game.strike(Vector3(-5, 0, 0), 3.0, 34.0)
	packet = _packet(source)
	sample_time.now = 4001
	t.ok(replica.accept(packet, 4, "boss_colossus"), "actual host strike accepted")
	AudioManager._last_played.erase("explode")
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(guest.controller.strike_sequence, game.strike_sequence, "guest mirrors actual strike sequence")
	t.equal(AudioManager._next_voice, (voice + 1) % AudioManager.SFX_VOICES, "fresh strike plays once")
	game.damage_boss(800.0, 0)
	packet = _packet(source)
	sample_time.now = 4501
	t.ok(replica.accept(packet, 4, "boss_colossus"), "actual host defeat accepted")
	for effect in ["hit", "powerup", "victory"]: AudioManager._last_played.erase(effect)
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.ok(guest.controller.boss_defeated and not guest.controller.boss_node.visible, "host defeat hides guest boss")
	t.equal(AudioManager._next_voice, (voice + 3) % AudioManager.SFX_VOICES, "fresh defeat feedback plays once")
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "duplicate defeat is silent")
	var defeated_reconnect := Replica.new()
	t.ok(defeated_reconnect.accept(packet, 4, "boss_colossus"), "reconnect accepts defeated host baseline")
	defeated_reconnect._last_phase = MatchPhase.P.PLAYING
	defeated_reconnect._last_round = 0
	for effect in ["hit", "powerup", "victory", "explode"]: AudioManager._last_played.erase(effect)
	voice = AudioManager._next_voice
	defeated_reconnect.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "reconnect does not replay old phase, strike or defeat")
	t.ok(guest.controller.boss_defeated and not guest.controller.boss_node.visible, "reconnect displays already defeated boss")
	replica = defeated_reconnect
	view = replica._colossus
	await host.get_tree().process_frame
	source._start_next_round()
	packet = _packet(source)
	t.ok(replica.accept(packet, 4, "boss_colossus"), "actual round reset snapshot remains valid")
	replica.render(guest, 0.016)
	t.empty(view.craters, "round baseline retires crater views")
	t.empty(guest.arena._crater_floor.holes, "round baseline restores guest floor")
	t.equal(guest.controller.boss_health, 800.0, "round baseline restores host health")
	var reconnect := Replica.new()
	t.ok(reconnect.accept(packet, 4, "boss_colossus"), "replacement accepts current baseline")
	reconnect._last_phase = MatchPhase.P.PLAYING
	reconnect._last_round = 1
	voice = AudioManager._next_voice
	reconnect.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "replacement baseline stays quiet")
	await host.get_tree().process_frame
	var views := 0
	for node in guest.ctx.world_root.get_children():
		if node.get_script() == View: views += 1
	t.equal(views, 1, "replacement retires previous visual nodes")
	t.ok(guest.arena._crater_floor._body == null, "replacement never recreates floor collider")
	for scene in scenes:
		scene.teardown()
		scene.queue_free()
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	AudioManager.enabled = audio_enabled


func _packet(scene: Node) -> Dictionary:
	var packet: Dictionary = JSON.parse_string(JSON.stringify(Replica.new().capture(scene)))
	packet.phase = MatchPhase.P.PLAYING
	return packet


func _colliders(node: Node) -> int:
	var count := 1 if node is CollisionObject3D else 0
	for child in node.get_children(): count += _colliders(child)
	return count
