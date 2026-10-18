extends RefCounted

const Service = preload("res://src/net/net_service.gd")


func _room() -> Dictionary:
	return {"op": "room", "code": "ABCD23", "host": 1, "capacity": 4, "state": "lobby",
		"config": {"game": "ring_rumble", "arena": "vortex_ring", "rounds": 3, "bots": true, "difficulty": 1},
		"tournament": null,
		"players": [{"id": 1, "slot": 0, "name": "Host", "character": 0, "ready": false, "connected": true},
			{"id": 2, "slot": 1, "name": "Guest", "character": 1, "ready": true, "connected": true}]}


func _state(service: Node) -> Dictionary:
	return {"code": service.room_code, "state": service.state, "mode": service.mode,
		"peers": service.peers.duplicate(true), "config": service.lobby_config.duplicate(true),
		"tournament": service.tournament.duplicate(true), "running": service.match_running,
		"pending": service._pending_result.duplicate(true), "inputs": service._inputs.duplicate(true)}


func run(t: TestHarness) -> void:
	t.suite("malformed lobby messages cannot replace session state")
	var invalid: Array[Dictionary] = []
	for field in ["id", "slot", "character"]:
		var message := _room()
		message.players[1][field] = message.players[0][field] if field != "character" else 999
		invalid.append(message)
	for field in ["rounds", "difficulty"]:
		var message := _room()
		message.config[field] = 0.5
		invalid.append(message)
	var game := _room()
	game.config.game = "missing_game"
	invalid.append(game)
	for field in ["code", "state"]:
		var message := _room()
		message[field] = "invalid"
		invalid.append(message)
	for message in invalid:
		var service := Service.new()
		service._receive(_room())
		service.match_running = true
		service._inputs = {1: {"held": true}}
		service._pending_result = {"epoch": 3}
		var before := _state(service)
		var updates: Array = []
		service.room_updated.connect(func(): updates.append(true))
		service._receive(message)
		t.equal(_state(service), before, "invalid room cannot partially clear or replace the valid session")
		t.equal(updates.size(), 0, "invalid room cannot refresh the lobby UI")
		service.free()
	t.suite("invalid welcome cannot replace reconnect identity")
	for message in [{"op": "welcome", "id": 0, "token": "fixture"},
			{"op": "welcome", "id": 1.5, "token": "fixture"},
			{"op": "welcome", "id": 1, "token": ""}]:
		var service := Service.new()
		service.local_peer_id = 9
		service._token = "fixture-old"
		service._retry_until = 700
		service._receive(message)
		t.equal(service.local_peer_id, 9, "invalid welcome preserves identity")
		t.equal(service._token, "fixture-old", "invalid welcome preserves reconnect token")
		t.equal(service._retry_until, 700, "invalid welcome does not cancel reconnect deadline")
		service.free()
	t.suite("malformed public rooms never reach the browser")
	var service := Service.new()
	var received: Array = []
	service.rooms_received.connect(func(rooms): received.append(rooms))
	service._receive({"op": "rooms", "rooms": [{"code": "ABCD23", "host": "Host", "count": 5, "capacity": 4}]})
	t.equal(received.size(), 0, "invalid occupancy is rejected before emission")
	service.free()
	_schema(t)
	_copy_isolation(t)


func _standings() -> Dictionary:
	return {"mode": "points", "target": 3, "round": 1, "points": [5, 3], "cups": [1, 0],
		"awards": [5, 3], "contenders": [], "champions": [], "tie_attempts": 0, "complete": false}


func _schema(t: TestHarness) -> void:
	t.suite("lobby schema supports current content and rejects malformed shapes")
	var service := Service.new()
	for game in Service.ONLINE_ARENAS:
		for arena in Service.ONLINE_ARENAS[game]:
			for state in ["lobby", "loading", "playing", "results"]:
				var message := _room()
				message.config.game = game
				message.config.arena = arena
				message.state = state
				message.tournament = _standings()
				t.ok(service._valid_room_message(JSON.parse_string(JSON.stringify(message))),
					"current game/arena and state accepts JSON protocol numbers")
	var holes := _room()
	holes.players[1].slot = 3
	t.ok(service._valid_room_message(holes), "lobby slot holes after a leave remain legal")
	holes.players.resize(1)
	t.ok(service._valid_room_message(holes), "host may wait alone before bots or guests join")
	for field in ["code", "state", "host", "capacity", "config", "players"]:
		for value in [null, true, "bad", [], {}, NAN, INF, -1, 0.5]:
			var message := _room()
			message[field] = value
			t.ok(not service._valid_room_message(message), "invalid room field rejected: " + field)
	for field in ["id", "slot", "character", "name", "ready", "connected"]:
		for value in [null, "bad", [], {}, NAN, INF, -1, 0.5]:
			var message := _room()
			message.players[1][field] = value
			if field == "name" and value is String:
				message.players[1][field] = "x".repeat(25)
			t.ok(not service._valid_room_message(message), "invalid peer field rejected: " + field)
	for field in ["mode", "target", "round", "points", "cups", "awards", "contenders", "champions", "tie_attempts", "complete"]:
		var view := _standings()
		view.erase(field)
		t.ok(not service._valid_tournament_view(view), "missing standings field rejected: " + field)
		for value in [null, "bad", {}, NAN, -1, 0.5]:
			view = _standings()
			view[field] = value
			t.ok(not service._valid_tournament_view(view), "malformed standings field rejected: " + field)
	for slots in [[0, 0], [-1], [2], [0.5]]:
		for field in ["contenders", "champions"]:
			var view := _standings()
			view[field] = slots
			t.ok(not service._valid_tournament_view(view), "invalid finalist slot is rejected")
	var settings := {"mode": "points", "target": 3, "rotation": "random_no_repeat",
		"points": [5, 3, 2, 1], "entries": [{"game": "ring_rumble", "arena": "vortex_ring"}]}
	var config: Dictionary = _room().config
	config.tournament = settings
	t.ok(service._valid_game_settings(config), "server tournament settings are supported")
	for field in ["mode", "target", "rotation", "points", "entries"]:
		for value in [null, "bad", {}, NAN, -1, 0.5]:
			var invalid := config.duplicate(true)
			invalid.tournament[field] = value
			t.ok(not service._valid_game_settings(invalid), "malformed tournament setting rejected: " + field)
	for points in [[5, 6, 2, 1], [5, 3, 2], [5, 3, 2, 0.5]]:
		var invalid := config.duplicate(true)
		invalid.tournament.points = points
		t.ok(not service._valid_game_settings(invalid), "invalid award table is rejected")
	var duplicate := config.duplicate(true)
	duplicate.tournament.entries.append(duplicate.tournament.entries[0].duplicate(true))
	t.ok(not service._valid_game_settings(duplicate), "duplicate playlist entry is rejected")
	var list := [{"code": "ABCD23", "host": "Host", "count": 1, "capacity": 4}]
	t.ok(service._valid_room_list([]), "empty public room list is legal")
	t.ok(service._valid_room_list(list), "valid public room is accepted")
	for value in [null, true, "bad", {}, 1, [null], [list[0], list[0]]]:
		t.ok(not service._valid_room_list(value), "malformed or duplicate room list is rejected")
	var oversized: Array = []
	oversized.resize(101)
	t.ok(not service._valid_room_list(oversized), "public room count respects server limit")
	for message in [{"op": "welcome"}, {"op": "welcome", "id": 1, "token": []},
			{"op": "welcome", "id": 1, "token": "x".repeat(129)}]:
		service._receive(message)
		t.equal(service._token, "", "invalid welcome never creates reconnect credentials")
	service.free()


func _copy_isolation(t: TestHarness) -> void:
	t.suite("accepted room and browser state do not alias incoming dictionaries")
	var service := Service.new()
	service._receive({"op": "welcome", "id": 1.0, "token": "fixture-valid"})
	t.equal(service.local_peer_id, 1, "JSON welcome installs identity")
	t.equal(service._token, "fixture-valid", "valid welcome installs its opaque token")
	var message := _room()
	message.tournament = _standings()
	service._receive(message)
	message.players[0].name = "Changed"
	message.config.rounds = 9
	message.tournament.points[0] = 999
	t.equal(service.peers[1].name, "Host", "peer state is a deep copy")
	t.equal(service.lobby_config.rounds, 3, "lobby config is a deep copy")
	t.equal(service.tournament.points[0], 5, "standings are a deep copy")
	var received: Array = []
	service.rooms_received.connect(func(rooms): received.append(rooms))
	var listing := {"op": "rooms", "rooms": [{"code": "ABCD23", "host": "Host", "count": 1, "capacity": 4}]}
	service._receive(listing)
	listing.rooms[0].host = "Changed"
	t.equal(received[0][0].host, "Host", "browser rows are independent copies")
	service.free()
