extends RefCounted

const Service = preload("res://src/net/net_service.gd")
const Client = preload("res://src/net/room_client.gd")


func run(t: TestHarness) -> void:
	t.suite("network ruleset identity is independent of replay revision")
	t.equal(Client.PROTOCOL_VERSION, 2, "wire protocol is not bumped")
	t.equal(Client.ONLINE_RULESET_ID, "atomic-v3", "integrated target has a fixed session identity")
	for version in [null, true, "1", 0, 2, 1.5, NAN, INF]:
		t.ok(not Client.compatible_hello({"op": "hello", "v": 2, "ruleset_version": version}),
			"old or malformed server cannot silently ignore ruleset")
	t.ok(not Client.compatible_hello({"op": "hello", "v": 2}), "old server without capability fails closed")
	t.ok(Client.compatible_hello({"op": "hello", "v": 2.0, "ruleset_version": 1.0}), "JSON integers remain legal")
	for operation in ["welcome", "room", "start"]:
		for ruleset in [null, "legacy", "atomic-v2", "future-4", 2, true, [], {}]:
			var service := Service.new()
			service._token = "old-opaque-fixture"
			service.match_running = true
			var starts: Array = []
			service.match_start_requested.connect(func(config): starts.append(config))
			var message := {"op": operation, "id": 1, "token": "new-opaque-fixture"}
			if ruleset != null:
				message.ruleset = ruleset
			service._receive(message)
			t.equal(starts.size(), 0, "incompatible start never launches simulation")
			t.ok(not service.match_running, "incompatible room terminates existing simulation")
			t.equal(service._token, "", "incompatible welcome never imports credentials")
			t.equal(service.failure_key, "online.version_mismatch", "existing localized terminal error is reused")
			service.free()
	t.ok(Client.compatible_ruleset({"ruleset": Client.ONLINE_RULESET_ID}), "matching immutable label is accepted")
