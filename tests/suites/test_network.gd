extends RefCounted

class RecordingTransport extends Node:
	var sent: Array = []
	func send(message: Dictionary) -> bool:
		sent.append(message.duplicate(true))
		return false


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
	for field in ["phase", "round", "countdown"]:
		invalid = packet.duplicate(true)
		invalid[field] = 0.5
		t.ok(not replica.accept(invalid, 2), "reject fractional " + field)
	for value in [-1, 11]:
		invalid = packet.duplicate(true)
		invalid.countdown = value
		t.ok(not replica.accept(invalid, 2), "reject countdown outside protocol bounds")
	for value in [0.5, 1000001, -1000001]:
		invalid = packet.duplicate(true)
		invalid.scores[0] = value
		t.ok(not replica.accept(invalid, 2), "reject malformed score")
	for field in ["health", "dash", "attack", "stun"]:
		invalid = packet.duplicate(true)
		invalid.fighters[0][field] = 10001
		t.ok(not replica.accept(invalid, 2), "reject excessive fighter " + field)
	for roster_size in [0, 1, 5]:
		invalid = packet.duplicate(true)
		invalid.fighters.clear()
		invalid.scores.clear()
		invalid.alive.clear()
		for slot in roster_size:
			invalid.fighters.append(body.duplicate(true))
			invalid.scores.append(0)
			invalid.alive.append(true)
		t.ok(not replica.accept(invalid, roster_size), "reject unsupported roster size")
	t.equal(replica.target.scores, [5, 3], "malformed packet cannot replace last valid state")
	t.ok(replica.accept(JSON.parse_string(JSON.stringify(packet)), 2), "JSON integer-valued floats remain valid")

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
	Net.match_data["tournament"] = JSON.parse_string('{"contenders": [0, 2], "complete": false}')
	var final_cfg := Net.make_match_config()
	t.equal(final_cfg.rule("online_contenders", []), [0, 2], "tie-break retains only authoritative contenders")
	t.equal(final_cfg.players.size(), 3, "spectators retain stable roster slots")
	t.equal(final_cfg.duration_override, 20.0, "tie-break is short")
	t.equal(final_cfg.rule("maximum_duration", 0), 25.0, "tie-break has a safety deadline")
	t.ok(not final_cfg.sudden_death, "room authority owns tournament tie resolution")
	Net._inputs[0] = {"time": Time.get_ticks_msec() - 300, "axes": [1, 0, 0, 0], "bits": 4}
	var frame := InputFrame.new()
	frame.bits = 4
	t.ok(not Net.consume_input(0, frame, 10), "stale inputs expire instead of moving forever")
	t.equal(frame.bits, 0, "stale held buttons are released")
	Net.leave()
	t.ok(Net._inputs.is_empty() and Net.match_data.is_empty(), "session cleanup clears remote state")

	t.suite("Network result replay protection")
	var results: Array = []
	var on_result := func(scores: Array): results.append(scores)
	Net.online_result.connect(on_result)
	Net.epoch = 3
	Net.room_state = "playing"
	Net._receive({"op": "result", "epoch": 2, "scores": [1, 0]})
	t.equal(results.size(), 0, "ignore another match's result")
	Net._receive({"op": "result", "epoch": 3, "scores": [5, 3], "tournament": {"points": [5, 3], "complete": false}})
	t.equal(Net.tournament.points, [5, 3], "standings arrive before the result UI")
	Net._receive({"op": "result", "epoch": 3, "scores": [5, 3]})
	t.equal(results.size(), 1, "reconnect does not apply the same result twice")
	Net.epoch = 4
	Net.room_state = "lobby"
	Net._receive({"op": "result", "epoch": 4, "scores": [5, 3]})
	t.equal(results.size(), 1, "lobby cannot receive a stale match result")
	Net.room_state = "playing"
	Net._receive({"op": "result", "epoch": 4, "scores": [3, 5]})
	t.equal(results.size(), 2, "next epoch can deliver its own result")
	Net.online_result.disconnect(on_result)
	Net.leave()

	t.suite("Network host result delivery")
	var transport := Net.transport
	var recorder := RecordingTransport.new()
	Net.transport = recorder
	Net.is_host = true
	Net.epoch = 8
	Net.room_state = "playing"
	var scores: Array[int] = [5, 3]
	Net.match_running = true
	Net.publish_result(scores)
	Net.publish_snapshot({}, 100)
	t.ok(not Net.match_running, "finishing stops snapshots before the server acknowledgement")
	scores[0] = 99
	t.equal(Net._pending_result.scores, [5, 3], "pending result owns an immutable copy")
	t.equal(recorder.sent.size(), 1, "result attempts immediate delivery")
	Net._receive({"op": "go", "epoch": 7})
	t.equal(recorder.sent.size(), 1, "stale go cannot resend a result")
	Net._receive({"op": "go", "epoch": 8})
	t.equal(recorder.sent.size(), 2, "resume retries the pending result")
	t.ok(not Net.match_running, "pending-result recovery cannot restart snapshot publication")
	Net._receive({"op": "result", "epoch": 8, "scores": [5, 3]})
	t.ok(Net._pending_result.is_empty(), "authoritative acknowledgement clears pending result")
	Net._receive({"op": "go", "epoch": 8})
	t.equal(recorder.sent.size(), 2, "acknowledged result is not sent again")
	t.ok(not Net.match_running, "late go cannot restart an acknowledged match")
	Net.transport = transport
	recorder.free()
	Net.leave()
