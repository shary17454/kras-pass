extends RefCounted

const Replica = preload("res://src/net/match_replica.gd")
const Dread = preload("res://src/net/dreadnought_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("dreadnought network presentation")
	var enabled: bool = AudioManager.enabled
	AudioManager.enabled = true
	var scenes: Array = []
	for peer in 2:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("boss_dreadnought", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 121), "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		scenes.append(scene)
	var source: Node = scenes[0]
	var guest: Node = scenes[1]
	var game: Node = source.controller
	var fighter: Fighter = source.ctx.fighter(0)
	fighter.global_position = game._vent.global_position
	fighter._attack_time = 0.2
	game._check_vent_hits(0)
	fighter._attack_time = 0.0
	t.equal(game.boss_health, 1055.0, "actual rear vent hit damages host")
	game._drop_mine()
	game.fire_shot(Vector3(5, 2, 0), Vector3.FORWARD, 21, 12, 30)
	game.telegraph(Vector3(6, 0, 0), 2.6, 1.3, func(_pos, _radius): pass)
	var packet := _packet(source)
	var replica := Replica.new()
	t.ok(replica.accept(packet, 4, "boss_dreadnought"), "actual host JSON accepted")
	var capture := FileAccess.open(SaveSystem.storage_root.path_join("dreadnought-world.json"), FileAccess.WRITE)
	t.ok(capture != null, "actual capture writable")
	if capture != null:
		capture.store_string(JSON.stringify(packet.world))
		capture.close()
	for count in [2, 3, 4]: t.ok(Dread.valid(packet.world, count), "bounded roster accepted")
	for field in packet.world.keys():
		var bad := packet.duplicate(true)
		bad.world.erase(field)
		t.ok(not replica.accept(bad, 4, "boss_dreadnought"), "missing world field rejected")
	for field in packet.world.boss.keys():
		var bad := packet.duplicate(true)
		bad.world.boss.erase(field)
		t.ok(not replica.accept(bad, 4, "boss_dreadnought"), "missing boss field rejected")
	for entry in [{"key": "health", "values": [-1, 1100.1, true, "1055", null, NAN, INF]},
		{"key": "phase", "values": [-1, 1, 0.5, true]}, {"key": "defeated", "values": [true, 0]},
		{"key": "rotation", "values": [[0, PI + 0.01, 0]]}]:
		for value in entry.values:
			var bad := packet.duplicate(true)
			bad.world.boss[entry.key] = value
			t.ok(not replica.accept(bad, 4, "boss_dreadnought"), "invalid boss field rejected")
	for group in ["warnings", "mines", "shots"]:
		for field in packet.world[group][0].keys():
			var bad := packet.duplicate(true)
			bad.world[group][0].erase(field)
			t.ok(not replica.accept(bad, 4, "boss_dreadnought"), "missing object field rejected")
		for id in ["", "01", "-1", "1.0", "1000000000000000000", 1, null]:
			var bad := packet.duplicate(true)
			bad.world[group][0].id = id
			t.ok(not replica.accept(bad, 4, "boss_dreadnought"), "invalid object id rejected")
		var bad := packet.duplicate(true)
		bad.world[group].append(bad.world[group][0].duplicate(true))
		t.ok(not replica.accept(bad, 4, "boss_dreadnought"), "duplicate object rejected")
		bad = packet.duplicate(true)
		bad.world[group][0].extra = 1
		t.ok(not replica.accept(bad, 4, "boss_dreadnought"), "extra field rejected")
		bad = packet.duplicate(true)
		bad.world[group] = []
		for index in (97 if group == "mines" else 65):
			var row: Dictionary = packet.world[group][0].duplicate(true)
			row.id = str(index + 10)
			bad.world[group].append(row)
		t.ok(not replica.accept(bad, 4, "boss_dreadnought"), "object population bounded")
	for value in [-1, 1.01, true, NAN]:
		var bad := packet.duplicate(true)
		bad.world.mines[0].armed = value
		t.ok(not replica.accept(bad, 4, "boss_dreadnought"), "invalid mine timer rejected")
	for direction in [[0, 0, 0], [2, 0, 0], [NAN, 0, 0]]:
		var bad := packet.duplicate(true)
		bad.world.shots[0].direction = direction
		t.ok(not replica.accept(bad, 4, "boss_dreadnought"), "invalid shell direction rejected")
	var bad := packet.duplicate(true)
	bad.world.mines[0].id = bad.world.shots[0].id
	t.ok(not replica.accept(bad, 4, "boss_dreadnought"), "cross-type duplicate rejected")
	t.equal(replica.target, packet, "invalid packet cannot replace host baseline")
	var probe := {"landed": false}
	guest.controller._drop_mine()
	guest.controller.fire_shot(Vector3.ZERO, Vector3.FORWARD, 21, 12, 30)
	guest.controller.telegraph(Vector3.ZERO, 2.6, 0.1, func(_p, _r): probe.landed = true)
	replica._last_phase = MatchPhase.P.PLAYING
	replica._last_round = 0
	var voice: int = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "initial baseline does not replay historical sounds")
	await host.get_tree().process_frame
	var view: Node = replica._dreadnought
	t.ok(guest.controller.presentation_only, "guest is presentation only")
	t.equal(guest.controller.boss_health, 1055.0, "host health displayed")
	t.equal(view.mines.size(), 1, "host mine displayed")
	t.equal(view.shots.size(), 1, "host shell displayed")
	t.equal(view.warnings.size(), 1, "host warning displayed")
	t.equal(_colliders(view), 0, "views cannot collide")
	t.empty(guest.controller._mines, "no local mine timers")
	t.empty(guest.controller._shots, "no local projectiles")
	t.empty(guest.controller._telegraphs, "no local warning callbacks")
	var scores := Array(guest.ctx.scores).duplicate()
	guest.controller.tick(10)
	guest.controller.boss_think(10)
	guest.controller.damage_boss(1100, 0)
	guest.controller._drop_mine()
	guest.controller._fire_shells(2)
	guest.controller._spin_up()
	guest.controller._tick_mines(10)
	guest.controller._check_vent_hits(10)
	guest.controller.boss_reset_round()
	guest.controller.on_phase_changed(2)
	t.equal(guest.controller.boss_health, 1055.0, "guest cannot damage or reset boss")
	t.equal(Array(guest.ctx.scores), scores, "guest cannot award score")
	t.ok(not guest.ctx.early_finish and not probe.landed, "guest cannot finish or trigger historical callbacks")
	t.empty(guest.controller._mines, "guest cannot spawn damaging mines")
	t.empty(guest.controller._shots, "guest cannot fire damaging shells")
	game.damage_boss(45, 0)
	packet = _packet(source)
	t.ok(replica.accept(packet, 4, "boss_dreadnought"), "fresh host damage accepted")
	AudioManager._last_played.erase("hit")
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, (voice + 1) % AudioManager.SFX_VOICES, "fresh damage plays once")
	t.equal(guest.controller.boss_health, 1010.0, "fresh health displayed")
	AudioManager._last_played.erase("hit")
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "duplicate damage does not replay sound")
	game._clear_mines()
	game._clear_shots()
	game._clear_telegraphs()
	game.damage_boss(1100, 0)
	packet = _packet(source)
	t.ok(replica.accept(packet, 4, "boss_dreadnought"), "host defeat accepted")
	replica.render(guest, 0.016)
	t.ok(guest.controller.boss_defeated and not guest.controller.boss_node.visible, "host defeat displayed")
	t.empty(view.mines, "removed mine views pruned")
	t.empty(view.shots, "removed shell views pruned")
	t.empty(view.warnings, "removed warning views pruned")
	source._start_next_round()
	packet = _packet(source)
	t.ok(replica.accept(packet, 4, "boss_dreadnought"), "host next round accepted")
	replica.render(guest, 0.016)
	t.equal(guest.controller.boss_health, 1100.0, "next round restores health")
	t.ok(guest.controller.boss_node.visible and not guest.controller.boss_defeated, "next round restores visible boss")
	var reconnect := Replica.new()
	t.ok(reconnect.accept(packet, 4, "boss_dreadnought"), "replacement replica accepts current baseline")
	reconnect._last_phase = MatchPhase.P.PLAYING
	reconnect._last_round = 1
	voice = AudioManager._next_voice
	reconnect.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "replacement baseline stays quiet")
	await host.get_tree().process_frame
	var views := 0
	for node in guest.ctx.world_root.get_children():
		if node.get_script() == Dread: views += 1
	t.equal(views, 1, "replacement retires old view")
	for scene in scenes:
		scene.teardown()
		scene.queue_free()
	AudioManager.enabled = enabled
	await host.get_tree().process_frame
	await host.get_tree().process_frame


func _packet(scene: Node) -> Dictionary:
	var packet: Dictionary = JSON.parse_string(JSON.stringify(Replica.new().capture(scene)))
	packet.phase = MatchPhase.P.PLAYING
	return packet


func _colliders(node: Node) -> int:
	var count := 1 if node is CollisionObject3D else 0
	for child in node.get_children(): count += _colliders(child)
	return count
