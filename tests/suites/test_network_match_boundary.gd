extends RefCounted

const Service = preload("res://src/net/net_service.gd")


func _session() -> Node:
	var service := Service.new()
	service.epoch = 3
	service.room_state = "playing"
	service.match_running = true
	service.match_data = {"config": {"game": "ring_rumble", "arena": "vortex_ring", "rounds": 1, "difficulty": 1},
		"players": [{"id": 1, "slot": 0, "name": "Host", "character": 0},
			{"id": 2, "slot": 1, "name": "Guest", "character": 1}]}
	service._pending_result = {"epoch": 3, "scores": [5, 3]}
	return service


func run(t: TestHarness) -> void:
	t.suite("invalid authoritative result cannot finish or acknowledge the match")
	for scores in [[], [1], [1, 2, 3], [NAN, 1], [INF, 1], [0.5, 1], [1000001, 1], [-1000001, 1]]:
		var service := _session()
		var results: Array = []
		service.online_result.connect(func(value): results.append(value))
		service._receive({"op": "result", "epoch": 3, "scores": scores})
		t.ok(service.match_running, "invalid scores do not stop the match")
		t.equal(service._result_epoch, -1, "invalid scores do not consume the epoch acknowledgement")
		t.equal(service._pending_result, {"epoch": 3, "scores": [5, 3]}, "invalid scores preserve pending result recovery")
		t.equal(results.size(), 0, "invalid scores never reach result presentation")
		service.free()
	t.suite("fractional epochs and snapshot ticks cannot advance match state")
	var service := _session()
	service._pending_result.clear()
	service.match_running = false
	service._receive({"op": "go", "epoch": 3.5})
	t.ok(not service.match_running, "fractional go cannot start simulation")
	service.is_host = false
	service._receive({"op": "snapshot", "epoch": 3, "tick": 1.5, "data": {}})
	t.equal(service._last_snapshot, -1, "fractional snapshot tick cannot replace the current stream")
	service.free()
	_result_contract(t)
	_envelope_contract(t)
	_recovery_and_replay(t)


func _standings() -> Dictionary:
	return {"mode": "points", "target": 3, "round": 1, "points": [5, 3], "cups": [1, 0],
		"awards": [5, 3], "contenders": [], "champions": [], "tie_attempts": 0, "complete": false}


func _result_contract(t: TestHarness) -> void:
	t.suite("result bounds follow catalogue direction and kart sentinels")
	var service := _session()
	for game in Service.ONLINE_GAMES:
		for rounds in [1, 10]:
			service.match_data.config.game = game
			service.match_data.config.arena = Service.ONLINE_ARENAS[game][0]
			service.match_data.config.rounds = rounds
			var maximum: int = 1000000000 * rounds if game in ["kart_sprint", "sabaq_sawarikh"] else 1000000
			var minimum := -1000000 if Registry.minigame(game).higher_is_better() else 0
			for value in [minimum, 0, maximum]:
				var message := {"op": "result", "epoch": 3, "scores": [value, 0]}
				t.ok(service._valid_result_message(message), "catalogue boundary accepted: " + game)
				t.ok(service._valid_result_message(JSON.parse_string(JSON.stringify(message))), "JSON result integers are accepted")
			for value in [minimum - 1, maximum + 1, NAN, INF, 0.5, true, "1"]:
				t.ok(not service._valid_result_message({"scores": [value, 0]}), "score outside contract rejected: " + game)
	service.match_data.config = _session_config()
	for scores in [null, false, "bad", {}, [], [1], [1, 2, 3]]:
		t.ok(not service._valid_result_message({"scores": scores}), "wrong result shape is rejected")
	for standings in [false, [], "bad", {"points": [5, 3], "complete": false}]:
		t.ok(not service._valid_result_message({"scores": [5, 3], "tournament": standings}), "incomplete standings cannot replace tournament state")
	var standings := _standings()
	t.ok(service._valid_result_message({"scores": [5, 3], "tournament": standings}), "complete standings are accepted")
	standings.points.append(0)
	standings.cups.append(0)
	standings.awards.append(0)
	t.ok(not service._valid_result_message({"scores": [5, 3], "tournament": standings}), "standing count must match active roster")
	service.match_data.config.tournament = {"mode": "points", "target": 3, "rotation": "manual",
		"points": [5, 3, 2, 1], "entries": [{"game": "ring_rumble", "arena": "vortex_ring"}]}
	t.ok(not service._valid_result_message({"scores": [5, 3]}), "tournament result cannot silently drop standings")
	t.ok(service._valid_result_message({"scores": [5, 3], "tournament": _standings()}), "tournament acknowledgement retains standings")
	service.free()


func _session_config() -> Dictionary:
	return {"game": "ring_rumble", "arena": "vortex_ring", "rounds": 1, "difficulty": 1}


func _envelope_contract(t: TestHarness) -> void:
	t.suite("match envelope rejects malformed metadata before conversion")
	var service := _session()
	for operation in ["go", "input", "snapshot", "result"]:
		for epoch in [null, false, "3", {}, [], NAN, INF, 0, -1, 3.5]:
			t.ok(not service._valid_match_envelope({"op": operation, "epoch": epoch}), "epoch is a positive finite integer")
	for field in ["slot", "sequence", "bits", "axes"]:
		for value in [null, false, "bad", {}, [], NAN, INF, -1, 0.5]:
			var message := {"op": "input", "epoch": 3, "slot": 1, "sequence": 1, "bits": 4, "axes": [0.5, 0, 1, 0]}
			message[field] = value
			t.ok(not service._valid_match_envelope(message), "malformed input field rejected: " + field)
	for axis in [NAN, INF, -1.01, 1.01, true, "0"]:
		t.ok(not service._valid_match_envelope({"op": "input", "epoch": 3, "slot": 1, "sequence": 1, "bits": 4, "axes": [axis, 0, 0, 0]}), "invalid input axis rejected")
	for value in [null, false, "bad", [], {}, NAN, INF, -1, 0.5]:
		t.ok(not service._valid_match_envelope({"op": "snapshot", "epoch": 3, "tick": value, "data": {}}), "invalid snapshot tick rejected")
		t.ok(not service._valid_match_envelope({"op": "pong", "stamp": value}), "invalid latency stamp rejected")
	for data in [null, false, "bad", [], 1]:
		t.ok(not service._valid_match_envelope({"op": "snapshot", "epoch": 3, "tick": 1, "data": data}), "snapshot data must be a dictionary")
	for operation in ["error", "closed"]:
		for value in [null, false, {}, [], "x".repeat(65)]:
			var message := {"op": operation}
			message["code" if operation == "error" else "reason"] = value
			t.ok(not service._valid_match_envelope(message), "malformed error/closure metadata rejected")
	service.free()


func _recovery_and_replay(t: TestHarness) -> void:
	t.suite("valid result recovery and input replay isolation")
	var service := _session()
	var results: Array = []
	service.online_result.connect(func(scores): results.append(scores))
	service._receive({"op": "result", "epoch": 3, "scores": [0.5, 1]})
	var message := {"op": "result", "epoch": 3, "scores": [5, 3]}
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(message))
	service._receive(decoded)
	decoded.scores[0] = 99
	t.equal(results[0][0], 5, "published result does not alias incoming score storage")
	t.equal(results.size(), 1, "valid result can follow an invalid attempt")
	t.ok(service._pending_result.is_empty(), "valid acknowledgement clears retry state")
	t.ok(not service.match_running, "valid result ends simulation")
	service._receive(message)
	t.equal(results.size(), 1, "valid result is applied only once")
	service.free()
	service = _session()
	service._receive({"op": "input", "epoch": 3, "slot": 1, "sequence": 2, "bits": 0, "axes": [0, 0, 0, 0]})
	service._receive({"op": "input", "epoch": 3, "slot": 1, "sequence": 1, "bits": 4, "axes": [1, 0, 0, 0]})
	var frame := InputFrame.new()
	t.ok(service.consume_input(1, frame, 1), "latest valid input stays available")
	t.equal(frame.bits, 0, "old press cannot reactivate a released attack")
	t.equal(frame.move, Vector2.ZERO, "old sequence cannot replace latest movement")
	t.ok(service._input_edges.is_empty(), "replayed input cannot queue a button edge")
	service.free()
