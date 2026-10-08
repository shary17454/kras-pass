extends RefCounted

class RecordingTransport extends Node:
	var sent: Array = []
	var accepted := false
	func send(message: Dictionary) -> bool:
		sent.append(message.duplicate(true))
		return accepted


class QuietReplica extends RefCounted:
	func render(_scene, _delta: float) -> void:
		pass


class ClosingTransport extends RecordingTransport:
	var closed := 0
	func close() -> void:
		closed += 1


func _endpoint_policy(t: TestHarness) -> void:
	t.suite("Network endpoint policy")
	var transport = load("res://src/net/room_client.gd").new()
	for url in ["wss://kras-pass-production.up.railway.app/multiplayer",
			"ws://127.0.0.1:8080/multiplayer", "ws://localhost:1/multiplayer",
			"ws://localhost:65535/multiplayer", "ws://127.0.0.1:08080/multiplayer?test=1"]:
		t.ok(transport.allowed_endpoint(url), "allow encrypted or canonical loopback endpoint")
	for url in ["", "http://localhost:8080/multiplayer", "ws://example.invalid/multiplayer",
			"ws://127.0.0.1:8080@example.invalid/multiplayer",
			"ws://localhost:8080@example.invalid/multiplayer",
			"ws://localhost:8080@127.0.0.1/multiplayer",
			"ws://localhost:8080.evil.invalid/multiplayer",
			"ws://localhost:0/multiplayer", "ws://localhost:65536/multiplayer",
			"ws://localhost:+8080/multiplayer", "ws://localhost:-1/multiplayer",
			"ws://localhost:/multiplayer", "ws://localhost:8080\\@example.invalid/multiplayer"]:
		t.ok(not transport.allowed_endpoint(url), "reject noncanonical plaintext authority")
		t.equal(transport.connect_room(url, {}), ERR_INVALID_PARAMETER, "reject before connection")
		t.equal(transport.socket, null, "rejection never creates socket")
	transport.free()


func run(t: TestHarness, host: Node) -> void:
	await _rotation_menu(t, host)
	await _mixed_playlist_menu(t, host)
	_protocol_policy(t)
	await _protocol_terminal_state(t, host)
	await _active_protocol_recovery(t, host)
	_endpoint_policy(t)
	_input_edges(t)
	_input_buffer_limits(t)
	_input_send_budget(t)
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
	_player_mapping(t)
	await _quick_draw_edges(t, host)


func _protocol_terminal_state(t: TestHarness, host: Node) -> void:
	t.suite("Network incompatible version recovery")
	for transport_failure in [true, false]:
		var service = load("res://src/net/net_service.gd").new()
		var recorder := ClosingTransport.new()
		service.transport = recorder
		service._token = "test-only-resume-token"
		service._retry_until = Time.get_ticks_msec() + 30000
		service._retry_at = 1
		service.room_code = "ABCDEF"
		service.match_running = true
		service.state = service.State.DISCONNECTED
		service.mode = service.Mode.ONLINE_CLIENT
		service.peers = {1: {"id": 1}}
		var errors: Array = []
		var closed: Array = []
		service.online_error.connect(func(code): errors.append(code))
		service.connection_lost.connect(func(reason): closed.append(reason))
		if transport_failure:
			service._transport_lost("protocol_mismatch")
		else:
			service._receive({"op": "error", "code": "version_mismatch"})
		t.equal(recorder.closed, 1, "incompatible transport is closed")
		t.equal(service._token, "", "resume token is cleared")
		t.equal(service._retry_until, 0, "reconnect deadline is cancelled")
		t.equal(service._retry_at, 0, "reconnect attempt is cancelled")
		t.equal(service.state, service.State.OFFLINE, "terminal mismatch returns offline")
		t.equal(service.mode, service.Mode.LOCAL, "local play is available")
		t.equal(service.room_code, "", "stale room identity is cleared")
		t.ok(service.peers.is_empty(), "stale roster is cleared")
		t.ok(not service.match_running, "no phantom active match")
		t.equal(errors, ["version_mismatch"], "specific error is emitted once")
		t.equal(closed, ["version_mismatch"], "active match gets terminal closure")
		t.equal(service.failure_key, "online.version_mismatch", "error persists for rebuilt room UI")
		service.host_local(4)
		t.equal(service.failure_key, "", "fresh local session clears previous error")
		t.equal(service.state, service.State.LOBBY, "local lobby still starts")
		service.free()
		recorder.free()
	var available := Net.online_available
	var locale := Loc.locale
	Net.reset()
	Net.online_available = true
	Net.failure_key = "online.version_mismatch"
	var screen = load("res://src/ui/screens/online_screen.gd").new()
	host.add_child(screen)
	for code in ["ar", "en"]:
		Loc.set_locale(code)
		screen.setup({}) if screen.body == null else screen._refresh()
		t.equal(screen._status.text, Loc.t("online.version_mismatch"), "rebuilt browser retains localized mismatch")
		t.ok(not screen._status.text.contains("online.version_mismatch"), "message resolves localization key")
	screen.queue_free()
	await host.get_tree().process_frame
	Net.reset()
	Net.online_available = available
	Loc.set_locale(locale)


func _rotation_menu(t: TestHarness, host: Node) -> void:
	t.suite("Online tournament rotation menu")
	var locale := Loc.locale
	var config := Net.lobby_config.duplicate(true)
	var mode := Net.mode
	Net.mode = Net.Mode.LOCAL
	for language in ["ar", "en"]:
		Loc.set_locale(language)
		for rotation in ["manual", "random", "random_no_repeat"]:
			Net.lobby_config = {"game": "ring_rumble", "arena": "storm_ring", "rounds": 3,
				"bots": true, "difficulty": 1, "tournament": {"mode": "points", "target": 3,
				"rotation": rotation, "points": [5, 3, 2, 1], "entries": [
					{"game": "ring_rumble", "arena": "vortex_ring"},
					{"game": "ring_rumble", "arena": "storm_ring"}]}}
			var screen = load("res://src/ui/screens/online_screen.gd").new()
			host.add_child(screen)
			screen.body = VBoxContainer.new()
			screen.add_child(screen.body)
			screen._host_settings()
			var select: OptionButton = screen.find_child("OnlineRotationSelect", true, false)
			t.ok(select != null, "rotation choice is exposed")
			t.equal(select.item_count, 3, "all three policies remain available")
			t.equal(select.selected, ["manual", "random", "random_no_repeat"].find(rotation), "server policy selects matching option")
			for index in 3:
				t.ok(not select.get_item_text(index).contains("online."), "rotation label resolves in both languages")
				select.item_selected.emit(index)
				t.equal(Net.lobby_config.tournament.rotation, ["manual", "random", "random_no_repeat"][index], "choice sends matching policy")
				t.equal(Net.lobby_config.tournament.entries.size(), 2, "changing rotation never discards selected entries")
				t.equal(Net.lobby_config.tournament.entries[0].arena, "vortex_ring", "playlist order is preserved")
			screen.queue_free()
			await host.get_tree().process_frame
	Net.lobby_config = config
	Net.mode = mode
	Loc.set_locale(locale)


func _mixed_playlist_menu(t: TestHarness, host: Node) -> void:
	t.suite("Online mixed minigame playlist editor")
	var locale := Loc.locale
	var config := Net.lobby_config.duplicate(true)
	var mode := Net.mode
	Net.mode = Net.Mode.LOCAL
	for language in ["ar", "en"]:
		Loc.set_locale(language)
		var cfg := {"game": "ring_rumble", "arena": "vortex_ring", "rounds": 3,
			"bots": true, "difficulty": 1, "tournament": {"mode": "points", "target": 3,
			"rotation": "manual", "points": [5, 3, 2, 1], "entries": [
				{"game": "ring_rumble", "arena": "vortex_ring"},
				{"game": "goal_guard", "arena": "quad_court"}]}}
		Net.lobby_config = cfg.duplicate(true)
		var screen = load("res://src/ui/screens/online_screen.gd").new()
		host.add_child(screen)
		screen.body = VBoxContainer.new()
		screen.add_child(screen.body)
		screen._host_settings()
		var select: OptionButton = screen.find_child("OnlinePlaylistGame1", true, false)
		t.equal(select.item_count, Net.ONLINE_GAMES.size(), "all registered online games are selectable")
		select.item_selected.emit(Net.ONLINE_GAMES.find("tank_arena"))
		t.equal(Net.lobby_config.tournament.entries[1].game, "tank_arena", "game selector changes only its playlist entry")
		t.equal(Net.lobby_config.tournament.entries[0], cfg.tournament.entries[0], "other entries are retained")
		var up: Button = screen.find_child("OnlinePlaylistUp1", true, false)
		up.pressed.emit()
		t.equal(Net.lobby_config.tournament.entries[0].game, "tank_arena", "move earlier preserves the preceding game edit")
		t.equal(Net.lobby_config.game, "tank_arena", "first entry and lobby game stay consistent")
		var remove: Button = screen.find_child("OnlinePlaylistRemove1", true, false)
		remove.pressed.emit()
		t.equal(Net.lobby_config.tournament.entries.size(), 1, "remove sends a shorter valid playlist")
		var add: Button = screen.find_child("OnlinePlaylistAdd", true, false)
		t.ok(not add.text.contains("online."), "add label is localized")
		add.pressed.emit()
		t.equal(Net.lobby_config.tournament.entries.size(), 2, "add preserves preceding removal and finds an unused pair")
		var selected_entries: Array = Net.lobby_config.tournament.entries.duplicate(true)
		var tournament_mode: OptionButton = screen.find_child("OnlineTournamentMode", true, false)
		for choice in [2, 1]:
			tournament_mode.item_selected.emit(choice)
			t.equal(Net.lobby_config.tournament.entries, selected_entries, "switching cups and points retains custom games")
			t.equal(Net.lobby_config.tournament.mode, "cups" if choice == 2 else "points", "scoring mode changes independently")
		var baseline: Dictionary = Net.lobby_config.duplicate(true)
		for invalid in [[], [cfg.tournament.entries[0], cfg.tournament.entries[0]],
				[{"game": "goal_guard", "arena": "vortex_ring"}], [{"game": "missing", "arena": "missing"}]]:
			t.ok(not screen._replace_playlist(cfg, invalid), "invalid or duplicate playlist rejected before publication")
			t.equal(Net.lobby_config, baseline, "rejection preserves room settings")
		var all: Array = []
		for id in Net.ONLINE_GAMES:
			all.append({"game": id, "arena": Net.ONLINE_ARENAS[id][0]})
		t.equal(all.size(), 39, "registry supports 39 different tournament games")
		t.ok(screen._replace_playlist(cfg, all), "39-game playlist accepted")
		all.append({"game": "ring_rumble", "arena": "storm_ring"})
		t.ok(not screen._replace_playlist(cfg, all), "server entry budget enforced locally")
		tournament_mode.item_selected.emit(0)
		select.item_selected.emit(0)
		add.pressed.emit()
		up.pressed.emit()
		remove.pressed.emit()
		t.equal(Net.lobby_config.tournament, null, "old editor callbacks cannot resurrect a disabled tournament")
		screen.queue_free()
		await host.get_tree().process_frame
	Net.lobby_config = config
	Net.mode = mode
	Loc.set_locale(locale)


func _protocol_policy(t: TestHarness) -> void:
	t.suite("Network protocol compatibility")
	var transport = load("res://src/net/room_client.gd").new()
	t.equal(transport.PROTOCOL_VERSION, 2, "snapshot revision uses protocol two")
	t.ok(transport.compatible_hello({"op": "hello", "v": 2}), "accept current server")
	t.ok(transport.compatible_hello(JSON.parse_string('{"op":"hello","v":2}')), "accept JSON numeric version")
	for version in [null, 0, 1, 3, 2.1, "2", true, false, NAN, INF]:
		t.ok(not transport.compatible_hello({"op": "hello", "v": version}), "reject incompatible or malformed version")
	t.ok(not transport.compatible_hello({"op": "welcome", "v": 2}), "require hello operation")
	transport.free()


func _input_edges(t: TestHarness) -> void:
	t.suite("Network input edges")
	t.test("a press and release received before a host tick remain distinct")
	Net.leave()
	Net.is_host = true
	Net.epoch = 3
	for packet in [
		{"op": "input", "epoch": 3, "slot": 1, "sequence": 1, "axes": [0.5, 0, 1, 0], "bits": 4},
		{"op": "input", "epoch": 3, "slot": 1, "sequence": 2, "axes": [0, 0, 0, 1], "bits": 0},
	]:
		Net._receive(packet)
	var frame := InputFrame.new()
	t.ok(Net.consume_input(1, frame, 1), "host receives queued press")
	t.ok(frame.just_pressed(InputFrame.Btn.ATTACK), "coalesced packets preserve attack press")
	t.equal(frame.aim, Vector2.RIGHT, "press retains its aiming intent")
	frame.prev_bits = frame.bits
	t.ok(Net.consume_input(1, frame, 2), "host receives queued release")
	t.ok(frame.just_released(InputFrame.Btn.ATTACK), "release follows on the next tick")
	t.equal(frame.aim, Vector2.DOWN, "release retains its aiming intent")
	Net.leave()

	t.test("guest physics publishes a one-tick press between movement samples")
	var saved_transport := Net.transport
	var recorder := RecordingTransport.new()
	recorder.accepted = true
	Net.transport = recorder
	Net.mode = Net.Mode.ONLINE_CLIENT
	Net.state = Net.State.IN_MATCH
	Net.is_host = false
	Net.local_peer_id = 2
	Net.peers = {2: {"slot": 1}}
	Net.match_running = true
	var scene = load("res://src/match/match_scene.gd").new()
	scene.config = MatchConfig.build("ring_rumble", ["nabta", "sakhra"], 1, 1, 51)
	scene.config.context = MatchConfig.Context.ONLINE
	scene.ctx = MatchContext.new()
	scene.ctx.config = scene.config
	scene._network_replica = QuietReplica.new()
	InputRouter.assign_virtual(1)
	InputRouter.frame(1).bits = InputFrame.Btn.ATTACK
	scene._physics_process(1.0 / 60.0)
	t.equal(recorder.sent.size(), 1, "odd physics tick publishes the short press")
	InputRouter.frame(1).bits = 0
	scene._physics_process(1.0 / 60.0)
	t.equal(recorder.sent.size(), 2, "release publishes even without a movement interval")
	var captured_press := false
	for packet in recorder.sent:
		captured_press = captured_press or int(packet.bits) == InputFrame.Btn.ATTACK
	t.ok(captured_press, "transport receives the attack, not only neutral input")
	scene.free()
	InputRouter.clear_all()
	Net.transport = saved_transport
	recorder.free()
	Net.leave()


func _active_protocol_recovery(t: TestHarness, host: Node) -> void:
	t.suite("Active online match incompatible version recovery")
	var available := Net.online_available
	for transport_failure in [true, false]:
		Net.reset()
		Net.online_available = true
		Net.mode = Net.Mode.ONLINE_CLIENT
		Net.is_host = false
		Net.local_peer_id = 8
		Net.peers = {8: {"slot": 1}}
		Net.room_code = "ABCDEF"
		Net.epoch = 1
		Net.room_state = "playing"
		Net.state = Net.State.IN_MATCH
		Net.match_running = true
		Net.match_data = {"config": {"game": "ring_rumble", "arena": "vortex_ring", "rounds": 1, "difficulty": 1},
			"seed": 2345, "players": [
				{"id": 1, "slot": 0, "name": "Host", "character": 0},
				{"id": 8, "slot": 1, "name": "Guest", "character": 1}]}
		var stats_before: Dictionary = Stats._s.duplicate(true)
		var replay_before := Replays.index().duplicate(true)
		var profile_before: Dictionary = SaveSystem.profile().duplicate(true)
		t.ok(await SceneRouter.go_to("match", {"config": Net.make_match_config()}, false, 0), "actual online route mounts")
		var match_node: Node = SceneRouter.current_node
		var match_ref := weakref(match_node)
		var world_ref := weakref(match_node.ctx.world_root)
		# Drive the mounted guest through the real snapshot/render pipeline.
		var snapshot: Dictionary = match_node._network_replica.capture(match_node)
		snapshot.phase = MatchPhase.P.PLAYING
		Net._receive({"op": "snapshot", "epoch": 1, "tick": 1, "data": snapshot})
		await host.get_tree().physics_frame
		await host.get_tree().process_frame
		t.equal(match_node.phase, MatchPhase.P.PLAYING, "guest is actually playing before mismatch")
		Net._token = "test-only-active-resume-token"
		Net._retry_until = Time.get_ticks_msec() + 30000
		if transport_failure:
			Net._transport_lost("protocol_mismatch")
		else:
			Net._receive({"op": "error", "code": "version_mismatch"})
		for frame in 120:
			await host.get_tree().process_frame
			if SceneRouter.current_id == "online" and not SceneRouter._busy and match_ref.get_ref() == null:
				break
		t.equal(SceneRouter.current_id, "online", "active failure returns to room browser")
		t.ok(match_ref.get_ref() == null, "previous match is actually freed")
		t.ok(world_ref.get_ref() == null, "previous world is actually freed")
		t.equal(SceneRouter.holder.get_child_count(), 1, "one replacement screen, no duplicate nodes")
		t.equal(SceneRouter.current_node._status.text, Loc.t("online.version_mismatch"), "replacement screen retains specific error")
		t.equal(Net._retry_until, 0, "active failure cancels reconnect deadline")
		t.equal(Net._token, "", "active failure clears resume token")
		t.equal(Stats._s, stats_before, "aborted match awards no statistics")
		t.equal(Replays.index(), replay_before, "aborted match stores no replay")
		t.equal(SaveSystem.profile(), profile_before, "aborted match awards no progression")
		Net.host_local(4)
		t.ok(await SceneRouter.go_to("local_play", {}, false, 0), "local play remains reachable after online failure")
		t.equal(Net.failure_key, "", "fresh local session clears failure")
		await SceneRouter.go_to("main_menu", {}, false, 0)
	Net.reset()
	Net.online_available = available


func _player_mapping(t: TestHarness) -> void:
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
	Net.match_data.config.game = "kart_sprint"
	Net.match_data.config.arena = "circuit_loop"
	Net.match_data.config.race_laps = 7
	var race_final := Net.make_match_config()
	t.equal(race_final.rule("race_laps", 0), 1, "race tiebreak uses one authoritative lap")
	t.ok(race_final.rule("party_short_race", false), "race tiebreak permits short lap count")
	t.equal(race_final.rule("maximum_duration", 0), 120.0, "race tiebreak has a driving safety deadline")
	Net.match_data.erase("tournament")
	var race_cfg := Net.make_match_config()
	t.equal(race_cfg.rule("race_laps", 0), 7, "ordinary race restores chosen host lap count")
	t.equal(race_cfg.rounds, 3, "match rounds and race laps remain independent")
	Net.match_data.config.erase("race_laps")
	t.equal(Net.make_match_config().rule("race_laps", 0), 3, "older race configuration defaults to three laps")
	Net.match_data.config.game = "sabaq_sawarikh"
	Net.match_data.config.arena = "dune_circuit"
	Net.match_data.config.race_laps = 10
	t.equal(Net.make_match_config().rule("race_laps", 0), 10, "armed race preserves host lap selection")
	Net.match_data["tournament"] = {"contenders": [0, 2]}
	var armed_final := Net.make_match_config()
	t.equal(armed_final.rule("race_laps", 0), 1, "armed race final uses one lap")
	t.ok(armed_final.rule("party_short_race", false), "armed race final permits short lap count")
	t.equal(armed_final.rule("maximum_duration", 0), 120.0, "armed race final has a driving safety deadline")
	t.equal(armed_final.rule("online_contenders", []), [0, 2], "armed race spectators retain stable roster slots")
	t.equal(Net.ONLINE_ARENAS.sabaq_sawarikh.size(), 8, "armed race exposes its eight authored courses")
	Net.match_data.config.game = "base_siege"
	Net.match_data.config.arena = "iron_flats"
	t.equal(Net.make_match_config().minigame_id, "base_siege", "siege uses shared online match configuration")
	t.equal(Net.make_match_config().rule("online_contenders", []), [0, 2], "siege final preserves contender roster")
	t.equal(Net.ONLINE_ARENAS.base_siege, ["iron_flats", "crate_yard"], "siege supports both original arenas")
	Net.match_data.config.game = "boss_forge"
	Net.match_data.config.arena = "crate_yard"
	t.equal(Net.make_match_config().minigame_id, "boss_forge", "forge uses shared online match configuration")
	t.equal(Net.make_match_config().rule("online_contenders", []), [0, 2], "forge final preserves contender roster")
	t.equal(Net.ONLINE_ARENAS.boss_forge, ["crate_yard"], "forge retains its authored arena")
	Net.match_data.erase("tournament")
	t.equal(Net.make_match_config().duration_override, 0.0, "ordinary forge retains authored duration")
	Net.match_data.config.game = "boss_dreadnought"
	Net.match_data.config.arena = "iron_flats"
	t.equal(Net.make_match_config().minigame_id, "boss_dreadnought", "dreadnought uses shared match configuration")
	t.equal(Net.ONLINE_ARENAS.boss_dreadnought, ["iron_flats"], "dreadnought retains authored arena")
	t.equal(Net.make_match_config().duration_override, 0.0, "ordinary dreadnought retains authored duration")
	Net.match_data["tournament"] = {"contenders": [0, 2]}
	t.equal(Net.make_match_config().rule("online_contenders", []), [0, 2], "dreadnought final preserves contender roster")
	Net.match_data.erase("tournament")
	Net.match_data.config.game = "boss_sovereign"
	Net.match_data.config.arena = "vortex_ring"
	t.equal(Net.make_match_config().minigame_id, "boss_sovereign", "sovereign uses shared match configuration")
	t.equal(Net.ONLINE_ARENAS.boss_sovereign, ["vortex_ring"], "sovereign retains authored arena")
	t.equal(Net.make_match_config().duration_override, 0.0, "ordinary sovereign retains authored duration")
	Net.match_data["tournament"] = {"contenders": [0, 2]}
	t.equal(Net.make_match_config().rule("online_contenders", []), [0, 2], "sovereign final preserves contender roster")
	Net.match_data.erase("tournament")
	Net.match_data.config.game = "boss_colossus"
	Net.match_data.config.arena = "vortex_ring"
	t.equal(Net.make_match_config().minigame_id, "boss_colossus", "colossus uses shared match configuration")
	t.equal(Net.ONLINE_ARENAS.boss_colossus, ["vortex_ring"], "colossus retains authored arena")
	t.equal(Net.make_match_config().duration_override, 0.0, "ordinary colossus retains authored duration")
	Net.match_data["tournament"] = {"contenders": [0, 2]}
	t.equal(Net.make_match_config().rule("online_contenders", []), [0, 2], "colossus final preserves contender roster")
	Net.match_data.erase("tournament")
	t.equal(Net.ONLINE_GAMES.size(), 39, "all catalogue games have development room adapters")
	for boss_id in ["boss_forge", "boss_dreadnought", "boss_sovereign", "boss_colossus"]:
		Net.match_data.config.game = boss_id
		var smoke_config := Net.make_match_config()
		smoke_config.duration_override = 15.0
		preload("res://tests/network_smoke_config.gd").configure_boss(smoke_config)
		t.equal(smoke_config.duration_override, 0.0, "actual ordinary boss smoke restores authored duration")
		Net.match_data["tournament"] = {"contenders": [0, 2]}
		smoke_config = Net.make_match_config()
		smoke_config.duration_override = 15.0
		preload("res://tests/network_smoke_config.gd").configure_boss(smoke_config)
		t.equal(smoke_config.duration_override, 20.0, "actual boss final smoke preserves short final")
		Net.match_data.erase("tournament")
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


func _packet(slot: int, bits: int, sequence := 1, epoch := 3) -> Dictionary:
	return {"op": "input", "epoch": epoch, "slot": slot, "sequence": sequence,
		"axes": [0.5, 0, 1, 0], "bits": bits}


func _input_buffer_limits(t: TestHarness) -> void:
	t.suite("Network bounded input buffering")
	t.test("every action retains its press and release exactly once")
	for bit in [InputFrame.Btn.JUMP, InputFrame.Btn.ACTION, InputFrame.Btn.ATTACK, InputFrame.Btn.DASH, InputFrame.Btn.ABILITY]:
		Net.leave()
		Net.epoch = 3
		Net._receive(_packet(1, bit))
		Net._receive(_packet(1, 0, 2))
		var frame := InputFrame.new()
		Net.consume_input(1, frame, 1)
		t.ok(frame.just_pressed(bit), "action press survives packet coalescing")
		frame.prev_bits = frame.bits
		Net.consume_input(1, frame, 2)
		t.ok(frame.just_released(bit), "action release remains ordered")
		frame.prev_bits = frame.bits
		Net.consume_input(1, frame, 3)
		t.ok(not frame.just_pressed(bit) and not frame.just_released(bit), "idle sample cannot replay an action")

	t.test("held buttons do not repeat and movements remain latest-value")
	Net.leave()
	Net.epoch = 3
	var original := _packet(1, 4)
	Net._receive(original)
	original.axes[0] = -1
	var frame := InputFrame.new()
	Net.consume_input(1, frame, 1)
	t.equal(frame.move.x, 0.5, "buffer owns its packet instead of a mutable caller reference")
	frame.prev_bits = frame.bits
	var latest := _packet(1, 4, 2)
	latest.axes[0] = -0.5
	Net._receive(latest)
	Net.consume_input(1, frame, 2)
	t.ok(frame.held(InputFrame.Btn.ATTACK) and not frame.just_pressed(InputFrame.Btn.ATTACK), "held attack does not duplicate its press")
	t.equal(frame.move.x, -0.5, "movement-only update is not delayed in an edge queue")
	t.ok(Net._input_edges[1].is_empty(), "unchanged held bits do not grow the queue")
	Net._receive(_packet(2, 8))
	Net.consume_input(2, InputFrame.new(), 3)
	t.equal(int(Net._inputs[1].bits), 4, "another player's dash cannot overwrite attack")
	Net._receive(_packet(1, 0, 3, 2))
	t.equal(int(Net._inputs[1].bits), 4, "stale-epoch release cannot overwrite live intent")

	t.test("queue and stale intent have strict bounds")
	Net.leave()
	Net.epoch = 3
	for i in 40:
		Net._receive(_packet(1, 4 if i % 2 == 0 else 0, i + 1))
	t.equal(Net._input_edges[1].size(), Net.MAX_INPUT_EDGES, "burst is bounded per player")
	for i in Net.MAX_INPUT_EDGES:
		Net.consume_input(1, frame, i)
	t.ok(Net._input_edges[1].is_empty(), "bounded burst drains instead of growing forever")
	t.equal(frame.bits, 0, "burst ultimately releases its held button")
	Net._receive(_packet(1, 4, 41))
	Net._input_edges[1][0]["time"] = Time.get_ticks_msec() - Net.INPUT_EXPIRY_MS - 1
	Net._receive(_packet(1, 0, 42))
	frame.prev_bits = 0
	Net.consume_input(1, frame, 1)
	t.ok(not frame.just_pressed(InputFrame.Btn.ATTACK), "expired press is not revived by a fresh release")
	Net._receive(_packet(1, 8, 43))
	Net._inputs[1]["time"] = Time.get_ticks_msec() - Net.INPUT_EXPIRY_MS - 1
	t.ok(not Net.consume_input(1, frame, 1), "stale held stream is rejected")
	t.ok(frame.bits == 0 and not Net._input_edges.has(1), "stale stream releases controls and discards transitions")

	t.test("new round, disconnect and session reset cannot replay old actions")
	Net._receive(_packet(1, 4, 44))
	Net._last_input_tick = 50
	Net._receive({"op": "start", "epoch": 4, "seed": 51,
		"config": {"game": "ring_rumble", "arena": "vortex_ring", "rounds": 1, "difficulty": 1},
		"players": [{"id": 1, "slot": 0, "name": "Host", "character": 0},
			{"id": 2, "slot": 1, "name": "Guest", "character": 1}]})
	t.ok(Net._inputs.is_empty() and Net._input_edges.is_empty(), "new epoch discards previous buttons")
	t.equal(Net._last_input_tick, -1, "new epoch permits immediate first input")
	Net._receive(_packet(1, 4, 1, 4))
	Net._pending_result = {"epoch": 4, "scores": [3, 0]}
	Net._transport_lost("test_disconnect")
	t.ok(Net._inputs.is_empty() and Net._input_edges.is_empty(), "disconnect discards pre-reconnect actions")
	t.ok(not Net._pending_result.is_empty(), "input cleanup cannot discard result retry")
	Net.leave()
	t.ok(Net._input_edges.is_empty(), "session reset clears every transition")


func _input_send_budget(t: TestHarness) -> void:
	t.suite("Network movement sampling")
	Net.leave()
	var saved_transport := Net.transport
	var recorder := RecordingTransport.new()
	recorder.accepted = true
	Net.transport = recorder
	Net.mode = Net.Mode.ONLINE_CLIENT
	Net.local_peer_id = 2
	Net.peers = {2: {"slot": 1}}
	Net.match_running = true
	var frame := InputFrame.new()
	for tick in 60:
		frame.move.x = float(tick) / 60.0
		Net.publish_input(1, frame, tick)
	t.equal(recorder.sent.size(), 30, "movement sends 30 packets per 60 physics ticks")
	Net.publish_input(1, frame, 59)
	t.equal(recorder.sent.size(), 30, "same-tick movement cannot duplicate a packet")
	frame.bits = InputFrame.Btn.ATTACK
	Net.publish_input(1, frame, 59)
	t.equal(recorder.sent.size(), 31, "button press bypasses movement sampling")
	frame.bits = 0
	Net.publish_input(1, frame, 60)
	t.equal(recorder.sent.size(), 32, "one-tick release bypasses movement sampling")
	Net.publish_input(0, frame, 61)
	t.equal(recorder.sent.size(), 32, "device cannot publish another owner's input")
	Net._clear_input_state()
	recorder.sent.clear()
	recorder.accepted = false
	Net.publish_input(1, frame, 1)
	recorder.accepted = true
	Net.publish_input(1, frame, 2)
	t.equal(recorder.sent.size(), 2, "failed transport does not suppress the following retry")
	Net.publish_input(1, frame, 0)
	t.equal(recorder.sent.size(), 3, "restarted tick counter permits a fresh sample")
	Net.transport = saved_transport
	recorder.free()
	Net.leave()


func _quick_draw_edges(t: TestHarness, host: Node) -> void:
	t.suite("Network reaction gameplay")
	t.test("coalesced short tap scores through the actual host physics pipeline")
	Net.leave()
	Net.mode = Net.Mode.ONLINE_HOST
	Net.state = Net.State.IN_MATCH
	Net.epoch = 7
	Net.peers = {1: {"slot": 0}, 2: {"slot": 1}}
	Net.match_data = {"epoch": 7, "seed": 53,
		"config": {"game": "quick_draw", "arena": "draw_stage", "rounds": 1, "difficulty": 1},
		"players": [{"id": 1, "slot": 0, "name": "Host", "character": 0},
			{"id": 2, "slot": 1, "name": "Guest", "character": 1}]}
	var cfg := Net.make_match_config()
	var scene = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_result): pass})
	scene.set_physics_process(false)
	t.ok(scene.ctx != null, "valid network match builds its actual context")
	if scene.ctx == null:
		scene.queue_free()
		Net.leave()
		await host.get_tree().process_frame
		return
	scene.phase = MatchPhase.P.PLAYING
	scene.ctx.phase = MatchPhase.P.PLAYING
	Net.match_running = true
	scene.controller._fire_signal()
	Net._receive(_packet(1, 4, 1, 7))
	Net._receive(_packet(1, 0, 2, 7))
	scene._physics_process(1.0 / 60.0)
	t.ok(scene.controller._order.has(1), "real quick draw receives the guest's short press")
	scene._physics_process(1.0 / 60.0)
	t.equal(scene.controller.correct_sequence, 1, "release does not duplicate a response")
	scene.controller._resolve()
	t.equal(scene.ctx.scores[1], 3, "guest earns normal reaction points")
	scene.teardown()
	scene.queue_free()
	Net.leave()
	await host.get_tree().process_frame
