extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("versioned authoritative Duel damage corrections")
	var config := MatchConfig.build("duel_pit", ["sakhra", "nabta"], 2, 1, 117)
	var packet := PackedByteArray()
	for slot in 2:
		packet.append_array(InputFrame.new().encode())
	var packets: Array = []
	for tick in 6:
		packets.append(packet.duplicate())
	var correction := PackedByteArray()
	correction.resize(2 * ReplayData.KEYFRAME_BYTES_PER_PLAYER)
	var data := ReplayData.from_match(config, packets, {}, {"6": correction}, null,
		{"6": [{"kind": "duel_damage", "damage": [4.0, 9.0]}]})
	var valid := data.to_dict()
	t.not_null(ReplayData.from_dict(valid), "current Duel corrections survive codec validation")
	var json := JSON.new()
	t.equal(json.parse(JSON.stringify(valid)), OK, "damage channel crosses JSON encoding")
	t.not_null(ReplayData.from_dict(json.data), "integer-valued JSON damage is accepted")
	var absent := valid.duplicate(true)
	absent["events"] = {}
	t.ok(ReplayData.from_dict(absent) == null, "new correctable Duel replay cannot silently omit damage")
	for revision in [0, 1, 2]:
		var historical := absent.duplicate(true)
		historical["combat_revision"] = revision
		var restored := ReplayData.from_dict(historical)
		t.not_null(restored, "historical revision %d requires no new channel" % revision)
		if restored != null:
			t.equal(restored.combat_revision, revision, "historical simulation revision is retained")
			t.not_null(ReplayData.from_dict(restored.to_dict()), "historical replay can be resaved without inventing damage")
	var input_only := absent.duplicate(true)
	input_only["keyframes_b64"] = ""
	input_only["keyframe_ticks"] = []
	t.not_null(ReplayData.from_dict(input_only), "input-only Duel has no unsupported corrections to guess")
	for values in [null, {}, "4,9", [], [4], [4, 9, 12], [-1, 9], [NAN, 9], [INF, 9],
			[false, 9], [4, ReplayData.MAX_DUEL_REPLAY_DAMAGE + 1.0]]:
		var malformed := valid.duplicate(true)
		malformed.events["6"][0]["damage"] = values
		t.ok(ReplayData.from_dict(malformed) == null, "invalid damage values are rejected before playback")
	for tick in ["0", "5", "12", "06", "6.0", "-6"]:
		var malformed := valid.duplicate(true)
		malformed["events"] = {tick: valid.events["6"].duplicate(true)}
		t.ok(ReplayData.from_dict(malformed) == null, "unpaired/noncanonical damage tick is rejected")
	var duplicate := valid.duplicate(true)
	duplicate.events["6"].append(duplicate.events["6"][0].duplicate(true))
	t.ok(ReplayData.from_dict(duplicate) == null, "duplicate damage correction cannot override the first")
	var extra := valid.duplicate(true)
	extra.events["6"][0]["other"] = true
	t.ok(ReplayData.from_dict(extra) == null, "unknown correction fields are rejected")
	for game in ["ring_rumble", "base_siege"]:
		var other := valid.duplicate(true)
		other["minigame_id"] = game
		t.ok(ReplayData.from_dict(other) == null, "Duel corrections cannot target another game")
	for revision in [0, 1, 2]:
		var historical := valid.duplicate(true)
		historical["combat_revision"] = revision
		t.ok(ReplayData.from_dict(historical) == null, "new correction cannot alter historical combat")
	_resource_limits(t, valid)
	var source := FileAccess.get_file_as_string("res://src/match/match_scene.gd")
	var start := source.find("\nfunc _tick_live(")
	var end := source.find("\nfunc ", start + 1)
	t.greater(start, -1, "real live-tick method exists")
	t.greater(end, start, "real live-tick body is bounded")
	var body := source.substr(start, end - start)
	for marker in ["_check_water_line()", "controller.process_respawns(delta)", "_record_or_apply_duel_damage()", "_evaluate_end(delta)"]:
		t.greater(body.find(marker), -1, "real live tick includes " + marker)
	t.ok(body.find("_check_water_line()") < body.find("_record_or_apply_duel_damage()"), "combat snapshot follows bounds and fall resets")
	t.ok(body.find("controller.process_respawns(delta)") < body.find("_record_or_apply_duel_damage()"), "combat snapshot follows respawn resets")
	t.ok(body.find("_record_or_apply_duel_damage()") < body.find("_evaluate_end(delta)"), "combat snapshot precedes round completion")
	t.equal(body.count("_record_or_apply_duel_damage()"), 1, "exactly one post-bounds dispatch occurs per live tick")
	await _runtime_scope(t, host, data)
	await _reset_boundaries(t, host)


func _resource_limits(t: TestHarness, valid: Dictionary) -> void:
	var generic := valid.duplicate(true)
	generic["minigame_id"] = "ring_rumble"
	var many: Array = []
	many.resize(ReplayData.EVENT_LIMIT)
	many.fill({"kind": "probe"})
	generic["events"] = {"6": many}
	t.not_null(ReplayData.from_dict(generic), "reader accepts the existing event-count boundary")
	many.append({"kind": "probe"})
	t.ok(ReplayData.from_dict(generic) == null, "reader rejects event-count budget overflow")
	var event := {"kind": "probe", "blob": ""}
	var overhead := JSON.stringify(event).to_utf8_buffer().size()
	event["blob"] = "x".repeat(ReplayData.EVENT_BYTE_LIMIT - overhead)
	generic["events"] = {"6": [event]}
	t.not_null(ReplayData.from_dict(generic), "reader accepts the exact existing serialized-byte budget")
	event["blob"] += "!"
	t.ok(ReplayData.from_dict(generic) == null, "reader rejects serialized-byte budget overflow")
	generic["events"] = {"6": [1]}
	t.ok(ReplayData.from_dict(generic) == null, "malformed event elements are rejected safely")


func _runtime_scope(t: TestHarness, host: Node, data: ReplayData) -> void:
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"replay": data})
	scene.set_physics_process(false)
	scene.set_process(false)
	scene._tick_index = 6
	var health: Array = []
	var lives: Array = []
	var position: Array = []
	for fighter in scene.ctx.fighters:
		fighter.damage_percent = 40.0
		health.append(fighter.health)
		lives.append(scene.controller.lives(fighter.slot))
		position.append(fighter.global_position)
	scene._apply_world_events()
	for fighter in scene.ctx.fighters:
		t.equal(fighter.damage_percent, 40.0, "pre-rules dispatch does not apply a post-bounds snapshot")
	scene._record_or_apply_duel_damage()
	for slot in 2:
		var fighter: Fighter = scene.ctx.fighter(slot)
		t.near(fighter.damage_percent, [4.0, 9.0][slot], 0.00001, "recorded damage replaces drift at correction tick")
		t.equal(fighter.health, health[slot], "damage correction does not fabricate health")
		t.equal(scene.controller.lives(slot), lives[slot], "damage correction does not fabricate stocks")
		t.equal(fighter.global_position, position[slot], "damage event never teleports a fighter")
	for revision in [0, 1, 2]:
		scene.playback.combat_revision = revision
		for fighter in scene.ctx.fighters:
			fighter.damage_percent = 40.0
		scene._record_or_apply_duel_damage()
		for fighter in scene.ctx.fighters:
			t.equal(fighter.damage_percent, 40.0, "legacy runtime path ignores a directly injected new event")
	scene.playback = null
	scene._world_events.clear()
	scene._replay_enabled = true
	scene._tick_index = 5
	scene._record_or_apply_duel_damage()
	t.ok(scene._world_events.is_empty(), "ordinary ticks do not grow the combat correction channel")
	scene._tick_index = 6
	scene._record_or_apply_duel_damage()
	t.equal(scene._world_events["6"][0]["damage"], [40.0, 40.0], "recording captures actual current damage")
	t.equal(scene._world_events["6"][0]["kind"], "duel_damage", "recording uses the bounded existing event channel")
	scene._world_events.clear()
	scene.config.minigame_id = "ring_rumble"
	scene._record_or_apply_duel_damage()
	t.ok(scene._world_events.is_empty(), "other games retain their existing event stream")
	scene.config.minigame_id = "duel_pit"
	scene._replay_event_count = ReplayData.EVENT_LIMIT
	scene._replay.append(InputFrame.new().encode())
	scene._keyframes["6"] = PackedByteArray([0])
	scene._record_or_apply_duel_damage()
	t.ok(not scene._replay_enabled, "overflow discards the recording rather than creating a channel-incomplete replay")
	t.ok(scene._replay.is_empty() and scene._keyframes.is_empty() and scene._world_events.is_empty(), "capture overflow releases every partial channel")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame


func _reset_boundaries(t: TestHarness, host: Node) -> void:
	# Injected unit fixtures deliberately place a fall or expiring respawn at
	# 6k-1/6k/6k+1; these are not natural replay or balance measurements.
	for boundary in [5, 6, 7]:
		for resetting in ["fall", "respawn", "round"]:
			var config := MatchConfig.build("duel_pit", ["sakhra", "nabta"], 2, 1, 117)
			config.allow_powerups = false
			config.sudden_death = false
			var scene: Node = load("res://src/match/match_scene.gd").new()
			host.add_child(scene)
			scene.setup({"config": config})
			scene.set_physics_process(false)
			scene.set_process(false)
			for slot in 2:
				InputRouter.assign_virtual(slot)
			var fighter: Fighter = scene.ctx.fighter(0)
			fighter.damage_percent = 41.0
			scene._replay_enabled = true
			if resetting == "round":
				scene._start_next_round()
			elif resetting == "respawn":
				fighter.alive = false
				fighter.visible = false
				fighter.global_position = Vector3(0, -500, 0)
				scene.controller._respawn_timers[0] = 1.0 / 60.0
			else:
				fighter.global_position.y = scene.arena.fall_y - 10.0
			scene.phase = scene.P.PLAYING
			scene._phase_locked = false
			scene._tick_index = boundary - 1
			await host.get_tree().physics_frame
			scene._tick_live(1.0 / 60.0)
			t.near(fighter.damage_percent, 0.0, 0.00001, "%s tick%d resets actual fighter damage" % [resetting, boundary])
			if resetting == "fall":
				t.equal(scene.controller.lives(0), 2, "real out-of-bounds handler spends exactly one life")
			else:
				t.equal(scene.controller.lives(0), 3, "respawn/round fixture cannot invent a stock loss")
			if boundary % ReplayData.KEYFRAME_INTERVAL != 0:
				t.ok(not scene._world_events.has(str(boundary)), "off-cadence reset creates no extra snapshot")
			while scene._tick_index % ReplayData.KEYFRAME_INTERVAL != 0:
				await host.get_tree().physics_frame
				scene._tick_live(1.0 / 60.0)
			var key := str(scene._tick_index)
			t.near(float(scene._world_events[key][0].damage[0]), 0.0, 0.00001, "next correction captures post-reset damage, never the pre-reset value")
			scene.teardown()
			scene.queue_free()
			await host.get_tree().process_frame
