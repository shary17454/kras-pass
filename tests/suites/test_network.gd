extends RefCounted


func run(t: TestHarness) -> void:
	t.suite("Network snapshot boundary")
	var replica = load("res://src/net/match_replica.gd").new()
	var body := {"position": [1.0, 2.0, 3.0], "velocity": [0.0, 0.0, 0.0], "facing": [0.0, 0.0, 1.0],
		"health": 100.0, "visible": true, "alive": true, "dash": 0.0, "attack": 0.0, "stun": 0.0}
	var packet := {"fighters": [body, body.duplicate(true)], "scores": [5, 3], "alive": [true, true],
		"time": 10.0, "phase": MatchPhase.P.PLAYING, "round": 0, "countdown": 3, "radius": 12.0}
	t.ok(replica.accept(packet, 2), "accept complete presentation snapshot")
	t.ok(not replica.accept(packet, 4), "reject wrong roster size")
	var invalid := packet.duplicate(true)
	invalid.fighters[0].position = [0.0, 1.0]
	t.ok(not replica.accept(invalid, 2), "reject truncated vector")
	invalid = packet.duplicate(true)
	invalid.fighters[0].health = NAN
	t.ok(not replica.accept(invalid, 2), "reject nonfinite state")
	invalid = packet.duplicate(true)
	invalid.radius = -2
	t.ok(not replica.accept(invalid, 2), "reject invalid radius")
	invalid = packet.duplicate(true)
	invalid.phase = 99
	t.ok(not replica.accept(invalid, 2), "reject invalid phase")
	t.equal(replica.target.scores, [5, 3], "malformed packet cannot replace last valid state")

	t.suite("Network player mapping")
	Net.leave()
	Net.local_peer_id = 8
	Net.peers = {8: {"slot": 1}}
	Net.match_data = {"config": {"game": "ring_rumble", "arena": "vortex_ring", "rounds": 3, "difficulty": 2},
		"seed": 2345, "players": [
			{"id": 1, "slot": 0, "name": "Host", "character": 0},
			{"id": 8, "slot": 1, "name": "Guest", "character": 1},
			{"id": 0, "slot": 2, "name": "", "character": 2}]}
	var cfg := Net.make_match_config()
	t.equal(cfg.human_slots(), [1], "only this device owns a human input")
	t.equal(cfg.players[0].peer_id, 1, "remote host identity is preserved")
	t.equal(cfg.players[2].peer_id, 0, "bot has no remote identity")
	t.equal(cfg.context, MatchConfig.Context.ONLINE, "network uses shared runtime")
	t.ok(cfg.rule("online_push", false), "explicit online variant")
	t.equal(cfg.seed, 2345, "same seed on every device")
	Net._inputs[0] = {"time": Time.get_ticks_msec() - 300, "axes": [1, 0, 0, 0], "bits": 4}
	var frame := InputFrame.new()
	frame.bits = 4
	t.ok(not Net.consume_input(0, frame, 10), "stale inputs expire instead of moving forever")
	t.equal(frame.bits, 0, "stale held buttons are released")
	Net.leave()
	t.ok(Net._inputs.is_empty() and Net.match_data.is_empty(), "session cleanup clears remote state")
