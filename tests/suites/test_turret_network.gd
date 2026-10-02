extends RefCounted

const Replica = preload("res://src/net/match_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("turret network presentation")
	var cfg := MatchConfig.build("turret_duel", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 117)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	scene.ctx.fighter(0).global_position = Vector3(100, 1, 100)
	game._fire(0)
	var pooled: Projectile = game._shots[0]
	scene.ctx.fighter(1).damage_percent = 13.5
	var replica = Replica.new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	packet.phase = MatchPhase.P.PLAYING
	t.ok(replica.accept(packet, 4, "turret_duel"), "serialized turret world accepted")
	for field in ["shots", "cooldowns", "damage"]:
		var bad := packet.duplicate(true)
		bad.world.erase(field)
		t.ok(not replica.accept(bad, 4, "turret_duel"), "missing world field rejected")
	for field in ["cooldowns", "damage"]:
		for value in [-1, INF, NAN, "1", true, 60.01 if field == "cooldowns" else 10001]:
			var bad := packet.duplicate(true)
			bad.world[field][0] = value
			t.ok(not replica.accept(bad, 4, "turret_duel"), "invalid host meter rejected")
		var bad := packet.duplicate(true)
		bad.world[field].pop_back()
		t.ok(not replica.accept(bad, 4, "turret_duel"), "wrong roster length rejected")
	for changes in [{"id": ""}, {"id": "0"}, {"id": "01"}, {"id": "+1"}, {"id": 1}, {"id": "1000000000000000000"},
		{"generation": 0}, {"generation": 1.5}, {"generation": "1"}, {"generation": true}, {"generation": 1000001},
		{"shooter": 4}, {"shooter": -1}, {"shooter": true}, {"shooter": 0.5}, {"position": [0, 0, 10001]},
		{"direction": [0, 0, 0]}, {"direction": [0, 1, 0]}, {"direction": [NAN, 0, 0]}, {"extra": 1}]:
		var bad := packet.duplicate(true)
		bad.world.shots[0].merge(changes, true)
		t.ok(not replica.accept(bad, 4, "turret_duel"), "invalid projectile row rejected")
	var bad := packet.duplicate(true)
	bad.world.shots.append(bad.world.shots[0].duplicate(true))
	t.ok(not replica.accept(bad, 4, "turret_duel"), "one pooled body cannot publish two live launches")
	bad = packet.duplicate(true)
	bad.world.extra = 1
	t.ok(not replica.accept(bad, 4, "turret_duel"), "extra world field rejected")
	bad = packet.duplicate(true)
	for index in 129:
		bad.world.shots.append({"id": str(index + 1), "generation": 1, "position": [0, 1, 0], "direction": [1, 0, 0], "shooter": 0})
	t.ok(not replica.accept(bad, 4, "turret_duel"), "projectile budget enforced")
	t.equal(replica.target, packet, "rejected data cannot replace valid snapshot")
	var enabled: bool = AudioManager.enabled
	AudioManager.enabled = true
	AudioManager._last_played.erase("swing")
	var voice: int = AudioManager._next_voice
	# Isolate launch audio from the shared HUD's legitimate "go" cue.
	replica._last_phase = MatchPhase.P.PLAYING
	replica._last_round = int(packet.round)
	replica.render(scene, 0.016)
	t.equal(AudioManager._next_voice, voice, "baseline cannot replay old shot audio")
	t.ok(game._shots.is_empty() and not pooled.active, "guest releases independent physics shots")
	t.equal(Pool.stats()[game.POOL_KEY].live, 0, "guest physics projectile returned to pool")
	t.equal(replica._turret.shots.size(), 1, "host projectile is visible")
	t.ok(not _has_collision(replica._turret), "guest visuals cannot collide or damage")
	t.equal(game._cooldowns[0], float(packet.world.cooldowns[0]), "host cooldown restored")
	t.equal(scene.ctx.fighter(1).damage_percent, 13.5, "host damage restored")
	var key: String = packet.world.shots[0].id + ":" + str(int(packet.world.shots[0].generation))
	var retained: Node3D = replica._turret.shots[key]
	var scores: Array = Array(scene.ctx.scores).duplicate()
	for repeat in 10:
		replica.render(scene, 0.016)
	t.equal(replica._turret.shots[key], retained, "same launch retains one visual")
	t.equal(Array(scene.ctx.scores), scores, "presentation cannot score hits")
	t.equal(game._cooldowns[0], float(packet.world.cooldowns[0]), "presentation cannot advance firing rules")
	packet.world.shots[0].position[0] += 1.0
	t.ok(replica.accept(packet, 4, "turret_duel"), "moving shot accepted")
	var before: Vector3 = retained.global_position
	replica.render(scene, 0.016)
	t.ok(retained.global_position.x > before.x and retained.global_position.x < before.x + 1.0, "shot motion interpolates")
	game._fire(0)
	t.equal(game._shots[0], pooled, "real pool reuses projectile body")
	var next: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	next.phase = MatchPhase.P.PLAYING
	t.equal(next.world.shots[0].id, packet.world.shots[0].id, "pool identity is stable")
	t.equal(int(next.world.shots[0].generation), int(packet.world.shots[0].generation) + 1, "every real firing increments launch generation")
	game.cleanup()
	AudioManager._last_played.erase("swing")
	voice = AudioManager._next_voice
	t.ok(replica.accept(next, 4, "turret_duel"), "new generation accepted")
	replica.render(scene, 0.016)
	t.equal(AudioManager._next_voice, (voice + 1) % AudioManager.SFX_VOICES, "new host launch plays audio once")
	t.ok(not retained.visible and retained.is_queued_for_deletion(), "recycled launch hides old trajectory")
	t.equal(replica._turret.shots.size(), 1, "new generation replaces old visual")
	voice = AudioManager._next_voice
	AudioManager._last_played.erase("swing")
	replica.render(scene, 0.016)
	t.equal(AudioManager._next_voice, voice, "duplicate cannot replay sound without debounce")
	next.world.shots[0].generation += 1
	t.ok(replica.accept(next, 4, "turret_duel"), "stale launch accepted for presentation")
	replica._event_received_at = replica.received_at - 1501
	replica.render(scene, 0.016)
	t.equal(AudioManager._next_voice, voice, "reconnect or stale update suppresses old launch sound")
	replica.render(scene, 0.016)
	t.equal(AudioManager._next_voice, voice, "suppressed event cannot replay later")
	next.round = 1
	next.phase = MatchPhase.P.INTRO
	next.world.shots[0].generation += 1
	t.ok(replica.accept(next, 4, "turret_duel"), "new round accepted")
	replica.render(scene, 0.016)
	t.equal(AudioManager._next_voice, voice, "new round establishes silent baseline")
	next.world.shots.clear()
	t.ok(replica.accept(next, 4, "turret_duel"), "expired shot update accepted")
	replica.render(scene, 0.016)
	t.ok(replica._turret.shots.is_empty(), "expired projectiles removed")
	AudioManager.enabled = enabled
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame


func _has_collision(node: Node) -> bool:
	if node is CollisionObject3D:
		return true
	for child in node.get_children():
		if _has_collision(child):
			return true
	return false
