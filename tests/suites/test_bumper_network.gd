extends RefCounted

const Replica = preload("res://src/net/match_replica.gd")
const Bumper = preload("res://src/net/bumper_replica.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("bumper network presentation")
	var cfg := MatchConfig.build("bumper_bowl", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 117)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	scene.controller.on_round_start()
	var bumpers: Array = []
	for hazard in scene.arena._hazards:
		if hazard is ArenaHazards.Bumper:
			bumpers.append(hazard)
			hazard._mesh.scale = Vector3(1.25, 0.8, 1.25)
			hazard.hit_serial = 4
	var replica = Replica.new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	t.equal(bumpers.size(), 5, "five authored bumpers covered")
	t.ok(replica.accept(packet, 4, "bumper_bowl"), "serialized bumper state accepted")
	for field in ["hits", "scales"]:
		var bad := packet.duplicate(true)
		bad.world.erase(field)
		t.ok(not replica.accept(bad, 4, "bumper_bowl"), "missing field rejected")
		bad = packet.duplicate(true)
		bad.world[field].pop_back()
		t.ok(not replica.accept(bad, 4, "bumper_bowl"), "wrong bumper count rejected")
	for value in [-1, 0.5, 1000001, NAN, INF, "1", true]:
		var bad := packet.duplicate(true)
		bad.world.hits[0] = value
		t.ok(not replica.accept(bad, 4, "bumper_bowl"), "invalid hit serial rejected")
	for scale in [[1, 1], [1, 1, 1, 1], [0.9, 1, 1], [1, 0.7, 1], [1, 1.1, 1], [1, 1, 1.3], ["1", 1, 1], [NAN, 1, 1], [INF, 1, 1], [true, 1, 1]]:
		var bad := packet.duplicate(true)
		bad.world.scales[0] = scale
		t.ok(not replica.accept(bad, 4, "bumper_bowl"), "invalid visual scale rejected")
	var bad := packet.duplicate(true)
	bad.world.extra = 1
	t.ok(not replica.accept(bad, 4, "bumper_bowl"), "unknown field rejected")
	scene.arena.reset_hazards()
	var scores: Array = Array(scene.ctx.scores).duplicate()
	replica.render(scene, 0.016)
	for bumper in bumpers:
		t.ok(bumper._mesh.scale.is_equal_approx(Vector3(1.25, 0.8, 1.25)), "host shape restored")
		t.ok(bumper._cooldowns.is_empty() and bumper.hit_serial == 0, "presentation cannot tick contacts")
		t.ok(bumper._bounce_tween == null, "presentation cannot create competing tweens")
	t.equal(Array(scene.ctx.scores), scores, "presentation cannot award points")
	var presenter = Bumper.new()
	var enabled: bool = AudioManager.enabled
	AudioManager.enabled = true
	AudioManager._last_played.erase("bounce")
	var voice: int = AudioManager._next_voice
	presenter.render(scene.controller, packet.world, 0, true)
	t.equal(AudioManager._next_voice, voice, "initial or reconnect baseline cannot replay old hit sounds")
	packet.world.hits[0] += 1
	presenter.render(scene.controller, packet.world, 0, true)
	t.equal(AudioManager._next_voice, (voice + 1) % AudioManager.SFX_VOICES, "new host hit plays feedback once")
	voice = AudioManager._next_voice
	AudioManager._last_played.erase("bounce")
	presenter.render(scene.controller, packet.world, 0, true)
	t.equal(AudioManager._next_voice, voice, "duplicate packet cannot replay sound even without audio debounce")
	packet.world.hits[0] += 1
	presenter.render(scene.controller, packet.world, 0, false)
	presenter.render(scene.controller, packet.world, 0, true)
	t.equal(AudioManager._next_voice, voice, "stale feedback is consumed without delayed replay")
	packet.world.hits[0] += 1
	presenter.render(scene.controller, packet.world, 1, true)
	t.equal(AudioManager._next_voice, voice, "new round establishes a fresh baseline")
	AudioManager.enabled = enabled
	scene.arena.reset_hazards()
	packet = replica.capture(scene)
	t.ok(replica.accept(packet, 4, "bumper_bowl"), "reset state accepted")
	replica.render(scene, 0.016)
	for bumper in bumpers:
		t.equal(bumper._mesh.scale, Vector3.ONE, "new round clears old deformation")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
