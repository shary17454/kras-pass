extends RefCounted

const Replica = preload("res://src/net/match_replica.gd")
const Siege = preload("res://src/net/siege_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("siege network presentation")
	var enabled: bool = AudioManager.enabled
	AudioManager.enabled = true
	var scenes: Array = []
	for peer in 2:
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build("base_siege", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 117), "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		scenes.append(scene)
	var source: Node = scenes[0]
	var guest: Node = scenes[1]
	var game: Node = source.controller
	var base: Dictionary = game._bases[1]
	var attacker: Fighter = source.ctx.fighter(0)
	attacker.facing = Vector3.FORWARD
	attacker.global_position = game._bases[0].node.global_position + Vector3(0, 0, 2)
	attacker.attacked.emit(0)
	t.equal(game.base_health(0), 100.0, "own crystal cannot be damaged by its owner")
	attacker.global_position = base.node.global_position + Vector3(0, 0, 2)
	attacker.attacked.emit(0)
	t.equal(base.health, 87.0, "real attack signal damages rival crystal")
	t.equal(base.hits, 1, "real attack records sampled hit generation")
	attacker.attacked.emit(0)
	t.equal(base.hits, 1, "cooldown rejects repeated swing")
	base.cooldown = 0.0
	attacker._dash_time = 0.1
	game._check_rams(base)
	t.equal(base.health, 78.0, "real charge chips rival crystal")
	t.equal(base.hits, 2, "charge records a separate hit generation")
	attacker._dash_time = 0.0
	var saved_cooldown: float = base.cooldown
	var saved_score: float = source.ctx.scores[0]
	base.cooldown = 0.0
	source.ctx.alive[0] = false
	attacker.attacked.emit(0)
	t.equal(base.health, 78.0, "eliminated slot cannot damage a crystal through stale attack signal")
	t.equal(source.ctx.scores[0], saved_score, "eliminated attack cannot award points")
	base.health = 78.0
	base.hits = 2
	base.cooldown = 0.0
	source.ctx.scores[0] = saved_score
	source.ctx.alive[0] = true
	attacker.alive = false
	attacker.attacked.emit(0)
	t.equal(base.health, 78.0, "falling inactive body cannot score stale attack")
	t.equal(source.ctx.scores[0], saved_score, "inactive attack cannot award points")
	base.health = 78.0
	base.hits = 2
	base.cooldown = 0.0
	source.ctx.scores[0] = saved_score
	attacker._dash_time = 0.1
	game._check_rams(base)
	t.equal(base.health, 78.0, "inactive dash cannot damage crystal")
	t.equal(source.ctx.scores[0], saved_score, "inactive dash cannot award points")
	base.health = 78.0
	base.hits = 2
	source.ctx.scores[0] = saved_score
	attacker.alive = true
	attacker._dash_time = 0.0
	base.cooldown = saved_cooldown
	var replica := Replica.new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(source)))
	packet.phase = MatchPhase.P.PLAYING
	t.ok(replica.accept(packet, 4, "base_siege"), "actual host JSON accepted")
	for count in [2, 3, 4]:
		var world: Dictionary = packet.world.duplicate(true)
		world.bases.resize(count)
		t.ok(Siege.valid(world, count), "base roster schema supports two to four players")
	var capture := FileAccess.open(SaveSystem.storage_root.path_join("siege-world.json"), FileAccess.WRITE)
	t.ok(capture != null, "actual host fixture writable in isolated test storage")
	if capture != null:
		capture.store_string(JSON.stringify(packet.world))
		capture.close()
	for field in ["health", "cooldown", "rotation", "height", "hits"]:
		var bad := packet.duplicate(true)
		bad.world.bases[0].erase(field)
		t.ok(not replica.accept(bad, 4, "base_siege"), "missing base field rejected")
		for value in [true, "1", null, NAN, INF]:
			bad = packet.duplicate(true)
			bad.world.bases[0][field] = value
			t.ok(not replica.accept(bad, 4, "base_siege"), "nonnumeric base field rejected")
	for entry in [{"field": "health", "values": [-1, 100.001]},
		{"field": "cooldown", "values": [-0.001, 0.301]},
		{"field": "rotation", "values": [-PI - 0.01, PI + 0.01]},
		{"field": "height", "values": [1.278, 1.422]},
		{"field": "hits", "values": [-1, 0.5, 1000001]}]:
		for value in entry.values:
			var bad := packet.duplicate(true)
			bad.world.bases[0][entry.field] = value
			t.ok(not replica.accept(bad, 4, "base_siege"), "out-of-bounds base field rejected")
	for count in [1, 2, 3, 5]:
		t.ok(not replica.accept(packet, count, "base_siege"), "incorrect roster rejected")
	for level in ["world", "base"]:
		var bad := packet.duplicate(true)
		if level == "world": bad.world.extra = 1
		else: bad.world.bases[0].extra = 1
		t.ok(not replica.accept(bad, 4, "base_siege"), "extra schema fields rejected")
	t.equal(replica.target, packet, "invalid snapshots cannot replace the last valid host state")
	replica._last_phase = MatchPhase.P.PLAYING
	replica._last_round = int(packet.round)
	var voice: int = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "initial snapshot does not replay prior hits")
	t.equal(guest.controller.base_health(1), 78.0, "guest HUD reads host base health")
	t.ok(guest.controller.presentation_only, "guest controller becomes presentation only")
	for view in guest.controller._bases:
		t.equal(view.body.collision_layer, 0, "guest crystal has no physics collision")
	t.near(guest.controller._bases[1].crystal.scale.x, lerpf(0.45, 1.0, 0.78), 0.001, "crystal scale reflects host health")
	var scores: Array = Array(guest.ctx.scores).duplicate()
	var alive: Array = Array(guest.ctx.alive).duplicate()
	var view: Dictionary = guest.controller._bases[1]
	guest.controller.tick(1.0)
	guest.controller._damage(view, 0, 100)
	guest.controller._destroy(view, 0)
	guest.controller._check_rams(view)
	guest.ctx.fighter(0).attacked.emit(0)
	guest.controller.on_round_start()
	t.equal(guest.controller.base_health(1), 78.0, "guest callbacks cannot damage or reset host health")
	t.equal(Array(guest.ctx.scores), scores, "guest callbacks cannot award points")
	t.equal(Array(guest.ctx.alive), alive, "guest callbacks cannot eliminate players")
	t.near(view.cooldown, 0.3, 0.001, "guest cannot advance authoritative cooldown")
	game._damage(base, 0, 100)
	t.equal(game.base_health(1), 0.0, "host destruction reaches zero health")
	t.ok(not source.ctx.is_alive(1), "only host destruction eliminates owner")
	t.ok(not base.node.visible, "host destroyed crystal is hidden")
	t.equal(base.body.collision_layer, 0, "host destroyed crystal stops colliding")
	packet = JSON.parse_string(JSON.stringify(replica.capture(source)))
	packet.phase = MatchPhase.P.PLAYING
	t.ok(replica.accept(packet, 4, "base_siege"), "real destruction accepted")
	for cue in ["crate_break", "explode"]: AudioManager._last_played.erase(cue)
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, (voice + 2) % AudioManager.SFX_VOICES, "fresh hit and destruction cues play once")
	t.ok(not view.node.visible, "guest destroyed base hidden")
	t.ok(not guest.ctx.is_alive(1), "guest elimination comes from host snapshot")
	for cue in ["crate_break", "explode"]: AudioManager._last_played.erase(cue)
	voice = AudioManager._next_voice
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "duplicate cues stay quiet without audio debounce")
	var reconnect := Replica.new()
	t.ok(reconnect.accept(packet, 4, "base_siege"), "reconnect accepts current destruction")
	reconnect._last_phase = MatchPhase.P.PLAYING
	reconnect._last_round = int(packet.round)
	reconnect.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "reconnect baseline does not replay destruction")
	source._start_next_round()
	voice = AudioManager._next_voice
	packet = JSON.parse_string(JSON.stringify(replica.capture(source)))
	packet.round = 1
	t.ok(replica.accept(packet, 4, "base_siege"), "next round accepted")
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "round reset is a quiet baseline")
	t.equal(guest.controller.base_health(1), 100.0, "next round restores host crystal health")
	t.ok(view.node.visible, "next round shows restored crystal")
	t.equal(view.body.collision_layer, 0, "round reset never restores guest collision")
	t.equal(base.body.collision_layer, 1, "host round reset restores solid cover")
	t.equal(view.hits, 0, "round reset clears sampled generations")
	packet.world.bases[0].hits += 1
	packet.phase = MatchPhase.P.PLAYING
	replica._last_phase = MatchPhase.P.PLAYING
	t.ok(replica.accept(packet, 4, "base_siege"), "delayed feedback snapshot remains valid state")
	replica._event_received_at = replica.received_at - 1501
	AudioManager._last_played.erase("crate_break")
	replica.render(guest, 0.016)
	t.equal(AudioManager._next_voice, voice, "delayed reconnect feedback remains quiet")
	for scene in scenes:
		scene.teardown()
		scene.queue_free()
	AudioManager.enabled = enabled
	await host.get_tree().process_frame
	await _check_final_spectators(t, host)


func _check_final_spectators(t: TestHarness, host: Node) -> void:
	var cfg := MatchConfig.build("base_siege", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 118)
	cfg.rules["online_contenders"] = [0, 2]
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	cfg.context = MatchConfig.Context.ONLINE
	scene.set_physics_process(false)
	for fighter in scene.ctx.fighters: fighter.set_physics_process(false)
	scene._begin_play()
	var game: Node = scene.controller
	for slot in [1, 3]:
		t.ok(not scene.ctx.is_alive(slot), "final spectators are inactive")
		t.equal(game.base_health(slot), 0.0, "spectator crystal cannot remain a scoring target")
		t.ok(not game._bases[slot].node.visible, "spectator crystal is hidden")
		t.equal(game._bases[slot].body.collision_layer, 0, "spectator crystal cannot obstruct final contenders")
	var attacker: Fighter = scene.ctx.fighter(0)
	attacker.facing = Vector3.FORWARD
	attacker.global_position = game._bases[1].node.global_position + Vector3(0, 0, 2)
	var before: float = scene.ctx.scores[0]
	attacker.attacked.emit(0)
	t.equal(scene.ctx.scores[0], before, "attacking spectator crystal cannot award points")
	t.equal(game._bases[1].hits, 0, "spectator crystal cannot record attack feedback")
	scene.ctx.scores[0] = before
	game._bases[1].cooldown = 0.0
	attacker._dash_time = 0.1
	game._check_rams(game._bases[1])
	t.equal(scene.ctx.scores[0], before, "ramming spectator crystal cannot award points")
	attacker._dash_time = 0.0
	attacker.global_position = game._bases[2].node.global_position + Vector3(0, 0, 2)
	attacker.attacked.emit(0)
	t.equal(game.base_health(2), 87.0, "active rival crystal still takes authored damage")
	t.equal(scene.ctx.scores[0], before + 1.0, "active rival still awards authored hit points")
	cfg.context = MatchConfig.Context.QUICK
	game.on_round_start()
	for slot in 4:
		t.equal(game.base_health(slot), 100.0, "offline restart ignores stale online contender metadata")
		t.ok(game._bases[slot].node.visible, "ordinary crystal visible after final")
		t.equal(game._bases[slot].body.collision_layer, 1, "ordinary crystal restores solid cover")
		game._bases[slot].hits = 5
	cfg.context = MatchConfig.Context.ONLINE
	var scores_before_reset: Array = Array(scene.ctx.scores).duplicate()
	game.on_round_start()
	t.equal(Array(scene.ctx.scores), scores_before_reset, "hiding spectator crystals cannot grant destruction points")
	for slot in [1, 3]:
		t.equal(game.base_health(slot), 0.0, "final restart does not resurrect spectator targets")
		t.equal(game._bases[slot].hits, 0, "final restart resets spectator feedback without scoring")
	var replica := Replica.new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	t.ok(replica.accept(packet, 4, "base_siege"), "actual spectator-final state remains valid for guest replication")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
