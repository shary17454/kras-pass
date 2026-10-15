extends RefCounted

const Service = preload("res://src/net/net_service.gd")


func _packet() -> Dictionary:
	return {"op": "start", "epoch": 7, "seed": 51,
		"config": {"game": "ring_rumble", "arena": "vortex_ring", "rounds": 1, "difficulty": 1},
		"players": [{"id": 1, "slot": 0, "name": "Host", "character": 0},
			{"id": 2, "slot": 1, "name": "Guest", "character": 1}]}


func run(t: TestHarness) -> void:
	t.suite("online start rejects invalid roster before mutating session")
	var invalid: Array[Dictionary] = []
	for field in ["id", "slot", "character"]:
		var message := _packet()
		message.players[1][field] = message.players[0][field] if field != "character" else 999
		invalid.append(message)
	for field in ["rounds", "difficulty"]:
		var message := _packet()
		message.config[field] = 0.5
		invalid.append(message)
	var missing_game := _packet()
	missing_game.config.game = "missing_game"
	invalid.append(missing_game)
	var wrong_arena := _packet()
	wrong_arena.config.arena = "tank_oasis"
	invalid.append(wrong_arena)
	var reordered := _packet()
	reordered.players.reverse()
	invalid.append(reordered)
	for message in invalid:
		var service := Service.new()
		service.epoch = 3
		service.match_data = {"sentinel": true}
		service._pending_result = {"epoch": 3, "scores": [5, 3]}
		service._inputs = {1: {"sentinel": true}}
		var starts: Array = []
		service.match_start_requested.connect(func(config): starts.append(config))
		service._receive(message)
		t.equal(service.epoch, 3, "invalid start preserves current epoch")
		t.equal(service.match_data, {"sentinel": true}, "invalid start preserves current match")
		t.equal(service._pending_result, {"epoch": 3, "scores": [5, 3]}, "invalid start preserves pending result")
		t.equal(service._inputs, {1: {"sentinel": true}}, "invalid start preserves input state")
		t.equal(starts.size(), 0, "invalid start never launches a scene")
		service.free()
	_schema_cases(t)
	_valid_and_stale_delivery(t)


func _schema_cases(t: TestHarness) -> void:
	t.suite("online start schema accepts current content and JSON numbers")
	var service := Service.new()
	for game in Service.ONLINE_ARENAS:
		for arena in Service.ONLINE_ARENAS[game]:
			for count in range(2, 5):
				var message := _packet()
				message.config.game = game
				message.config.arena = arena
				message.players = []
				for slot in count:
					message.players.append({"id": 1 if slot == 0 else 0, "slot": slot,
						"character": slot, "name": "Host" if slot == 0 else ""})
				t.ok(service._valid_start_message(message), "current game/arena accepts humans plus repeated bot IDs")
				t.ok(service._valid_start_message(JSON.parse_string(JSON.stringify(message))),
					"JSON floating-point integers preserve the protocol contract")
	for field in ["epoch", "seed"]:
		for value in [null, true, "7", [], {}, NAN, INF, -1, 0.5, 9007199254740992.0]:
			var message := _packet()
			message[field] = value
			t.ok(not service._valid_start_message(message), "malformed epoch/seed is rejected")
	for field in ["config", "players"]:
		for value in [null, false, "bad", 1, []]:
			var message := _packet()
			message[field] = value
			t.ok(not service._valid_start_message(message), "missing or wrong-shaped match data is rejected")
	for field in ["id", "slot", "character", "name"]:
		var missing := _packet()
		missing.players[1].erase(field)
		t.ok(not service._valid_start_message(missing), "missing player field is rejected")
		for value in [null, false, [], {}, NAN, INF, -1, 0.5]:
			var message := _packet()
			message.players[1][field] = value
			t.ok(not service._valid_start_message(message), "wrong player field type is rejected")
	var long_name := _packet()
	long_name.players[1].name = "x".repeat(25)
	t.ok(not service._valid_start_message(long_name), "oversized name is rejected")
	var absent := _packet()
	absent.players[0].id = 3
	t.ok(not service._valid_start_message(absent), "start cannot assign a match without the local peer")
	for value in [null, true, {}, "bad", [0, 0], [-1], [2], [0.5]]:
		var message := _packet()
		message.tournament = {"contenders": value}
		t.ok(not service._valid_start_message(message), "invalid sudden-death contenders are rejected")
	var contenders := _packet()
	contenders.tournament = {"contenders": [0, 1]}
	t.ok(service._valid_start_message(contenders), "valid sudden-death contenders are preserved")
	service.free()


func _valid_and_stale_delivery(t: TestHarness) -> void:
	t.suite("valid online start and stale-epoch replay")
	var service := Service.new()
	var starts: Array = []
	service.match_start_requested.connect(func(config): starts.append(config))
	var message := _packet()
	service._receive(message)
	t.equal(starts.size(), 1, "valid start launches one match")
	t.equal(service.epoch, 7, "valid start installs the server epoch")
	t.equal(starts[0].players.size(), 2, "valid roster is converted to MatchConfig")
	message.players[0].name = "Changed after delivery"
	t.equal(service.match_data.players[0].name, "Host", "accepted state is an independent copy")
	var before := service.match_data.duplicate(true)
	var stale := _packet()
	stale.epoch = 6
	service._receive(stale)
	t.equal(service.epoch, 7, "older start cannot rewind the current match")
	t.equal(service.match_data, before, "older start cannot replace the accepted roster")
	t.equal(starts.size(), 1, "older start cannot launch a second scene")
	service.free()
