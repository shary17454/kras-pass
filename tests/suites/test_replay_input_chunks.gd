extends RefCounted

func run(t: TestHarness, host: Node) -> void:
	t.suite("bounded replay input chunks")
	for players in range(1, 5):
		var buffer := ReplayInputBuffer.new()
		var packet := PackedByteArray()
		packet.resize(players * InputFrame.BYTES)
		var count := ReplayInputBuffer.CHUNK_TICKS * 5 + 7
		for tick in count:
			packet.encode_u16(0, tick % 65536)
			buffer.append(packet)
		t.equal(buffer.size(), count, "long capture retains all ticks for %d players" % players)
		t.equal(buffer._chunks.size(), 5, "five minutes use five sealed chunks, not per-tick entries")
		t.equal(buffer.byte_size(), count * packet.size(), "byte accounting is exact")
		for tick in [0, 3599, 3600, 14399, 14400, count - 1]:
			t.equal(buffer.packet_at(tick).decode_u16(0), tick % 65536, "tick survives chunk boundary %d" % tick)
		t.ok(buffer.packet_at(-1).is_empty(), "negative tick is rejected")
		t.ok(buffer.packet_at(count).is_empty(), "past-end tick is rejected")
		var snapshot := buffer.snapshot()
		buffer.append(packet)
		t.equal(snapshot.size(), count, "snapshot cannot gain subsequently recorded ticks")
		buffer.clear()
		t.equal(snapshot.packet_at(count - 1).decode_u16(0), (count - 1) % 65536, "clearing capture does not mutate saved snapshot")
		var flat := snapshot.flatten()
		var decoded := ReplayInputBuffer.from_flat(flat, packet.size())
		t.equal(decoded.size(), snapshot.size(), "legacy flat file reconstructs compact chunks")
		t.equal(decoded.flatten(), flat, "flattened compatibility payload is byte identical")
		flat[0] = 255
		t.equal(decoded.packet_at(0).decode_u16(0), 0, "external flat input cannot mutate loaded buffer")
		t.ok(not decoded.append(PackedByteArray([1])), "mismatched packet stride is refused")
		t.equal(decoded.size(), count, "malformed append leaves buffer unchanged")
	t.ok(ReplayInputBuffer.from_flat(PackedByteArray([1]), 0).is_empty(), "invalid flat stride is refused")
	t.ok(ReplayInputBuffer.from_flat(PackedByteArray([1]), 2).is_empty(), "partial flat packet is refused")
	_event_budget(t)
	await _long_match(t, host)


func _event_budget(t: TestHarness) -> void:
	var scene: Node = load("res://src/match/match_scene.gd").new()
	scene._replay_enabled = true
	var event := {"position": [1, 2, 3]}
	scene._record_world_event("probe", event)
	event.position[0] = 1000
	t.equal(scene._world_events["0"][0].position[0], 1, "recorded event cannot grow or change through caller alias")
	scene._replay_event_count = scene.REPLAY_EVENT_LIMIT
	scene._replay.append(InputFrame.new().encode())
	scene._keyframes["0"] = PackedByteArray([0])
	scene._record_world_event("probe", {})
	t.ok(not scene._replay_enabled, "event-count exhaustion stops complete capture")
	t.ok(scene._replay.is_empty(), "event-count exhaustion releases inputs")
	t.empty(scene._keyframes, "event-count exhaustion releases corrections")
	scene._replay_enabled = true
	scene._replay_event_bytes = scene.REPLAY_EVENT_BYTE_LIMIT
	scene._record_world_event("probe", {})
	t.ok(not scene._replay_enabled, "event-byte exhaustion stops complete capture")
	t.equal(scene._replay_event_bytes, 0, "discard resets byte accounting")
	scene.free()


func _long_match(t: TestHarness, host: Node) -> void:
	var previous = UserSettings.get_value("replay_capture")
	UserSettings.set_value("replay_capture", true)
	var fixture = load("res://tests/suites/test_replay.gd").new()
	var cfg := MatchConfig.build("zone_hold", ["nabta", "sakhra", "fanoos", "ramla"], 0, 2, 31337)
	cfg.duration_override = 250.0
	cfg.rounds = 1
	var live: Dictionary = await fixture._play(host, {"config": cfg}, 330.0)
	t.not_null(live.result, "long match reaches natural result")
	if live.result != null:
		var entry: Dictionary = Replays.index()[0]
		var data := Replays.load_replay(String(entry.id))
		t.not_null(data, "long match saves and reloads")
		if data != null:
			t.greater(data.tick_count(), 60 * 240, "recording extends past former four-minute cutoff")
			var played: Dictionary = await fixture._play(host, {"replay": data}, 330.0)
			t.not_null(played.result, "long replay reaches the end")
			if played.result != null:
				t.equal(str(played.result.scores), str(live.result.scores), "long replay preserves scores")
				t.equal(str(played.result.places), str(live.result.places), "long replay preserves places")
			t.equal(played.desync, -1, "long replay has no unrecoverable divergence")
			t.equal(played.errors, 0, "long playback logs no errors")
		Replays.erase(String(entry.id))
	UserSettings.set_value("replay_capture", previous)
