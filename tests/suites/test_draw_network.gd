extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("draw network presentation")
	var cfg := MatchConfig.build("quick_draw", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 106)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	var replica = load("res://src/net/match_replica.gd").new()
	var packet: Dictionary = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	packet.phase = MatchPhase.P.PLAYING
	t.ok(replica.accept(packet, 4, "quick_draw"), "wait state survives JSON")
	t.ok(not packet.world.has("timer") and not packet.world.has("signal_age"), "hidden wait is never published")
	for field in packet.world.keys():
		var bad := packet.duplicate(true)
		bad.world.erase(field)
		t.ok(not replica.accept(bad, 4, "quick_draw"), "reject missing " + field)
	for field in ["stage", "prompt", "signal_sequence", "correct_sequence", "wrong_sequence", "resolve_sequence"]:
		for value in [null, true, "1", NAN, INF, -1, 0.5, 1000001]:
			var bad := packet.duplicate(true)
			bad.world[field] = value
			t.ok(not replica.accept(bad, 4, "quick_draw"), "reject invalid " + field)
	for changes in [{"stage": 3}, {"timer": 2}, {"order": [0]}, {"stage": 1, "order": [0, 0]},
		{"stage": 1, "order": [4]}, {"stage": 1, "order": [true]}, {"locked": [0, false, false, false]},
		{"stage": 1, "order": [0], "locked": [true, false, false, false]}]:
		var bad := packet.duplicate(true)
		bad.world.merge(changes, true)
		t.ok(not replica.accept(bad, 4, "quick_draw"), "reject inconsistent prompt")
	t.equal(replica.target, packet, "invalid data preserves previous snapshot")
	AudioManager._last_played.erase("go")
	replica.render(scene, 0.1)
	t.ok(not AudioManager._last_played.has("go"), "initial snapshot stays silent")
	game._fire_signal()
	t.equal(game.signal_sequence, 1, "host signal increments event sequence")
	packet = JSON.parse_string(JSON.stringify(replica.capture(scene)))
	packet.phase = MatchPhase.P.PLAYING
	AudioManager._last_played.erase("go")
	t.ok(replica.accept(packet, 4, "quick_draw"), "accept signalled host state")
	replica.render(scene, 0.1)
	t.ok(game.is_signalled(), "guest sees signal")
	t.equal(game._pillar.material_override.albedo_color, Color("#ffd23f"), "pillar displays host signal")
	if AudioManager.enabled:
		t.ok(AudioManager._last_played.has("go"), "fresh signal plays once")
	AudioManager._last_played.erase("go")
	var scores := Array(scene.ctx.scores)
	var timer: float = game._timer
	for repeat in 10:
		replica.render(scene, 1.0)
	t.ok(not AudioManager._last_played.has("go"), "duplicate signal remains silent")
	t.equal(Array(scene.ctx.scores), scores, "render cannot award points")
	t.near(game._timer, timer, 0.00001, "render cannot advance rules")
	packet.world.order = [2, 0]
	packet.world.locked[1] = true
	packet.world.correct_sequence += 2
	packet.world.wrong_sequence += 1
	t.ok(replica.accept(packet, 4, "quick_draw"), "accept response order and false start")
	replica.render(scene, 0.1)
	t.equal(Array(game._order), [2, 0], "guest displays host ranking")
	t.ok(game.is_locked(1), "guest displays host false start")
	packet.world.stage = 2
	packet.world.resolve_sequence += 1
	t.ok(replica.accept(packet, 4, "quick_draw"), "accept resolution")
	replica.render(scene, 0.1)
	t.equal(game._pillar.material_override.albedo_color, UIKit.PANEL_HI, "resolution clears signal")
	packet.world.signal_sequence += 1
	AudioManager._last_played.erase("go")
	t.ok(replica.accept(packet, 4, "quick_draw"), "accept reconnect")
	replica._event_received_at = replica.received_at - 1501
	replica.render(scene, 0.1)
	t.ok(not AudioManager._last_played.has("go"), "reconnect skips historical signal audio")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
