extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("Duel compound profile lifecycle and historical combat routing")
	for game in ["duel_pit", "ring_rumble"]:
		for revision in [-1, 0, 1, 2, 3]:
			t.test("%s combat revision %d" % [game, revision])
			var config := MatchConfig.build(game, ["sakhra", "turs", "ghaim", "fanoos"], 4, 1, 117)
			config.rounds = 2
			var args := {"config": config}
			if revision >= 0:
				var replay := ReplayData.from_match(config, [], {}, {}, null)
				replay.combat_revision = revision
				var packet := PackedByteArray()
				for slot in 4:
					packet.append_array(InputFrame.new().encode())
				for tick in 4:
					replay.frames.append(packet.duplicate())
				args = {"replay": replay}
			var scene: Node = load("res://src/match/match_scene.gd").new()
			host.add_child(scene)
			scene.setup(args)
			scene.set_physics_process(false)
			scene.set_process(false)
			var enabled: bool = game == "duel_pit" and (revision < 0 or revision >= 3)
			for fighter in scene.ctx.fighters:
				_check_profile(t, fighter, enabled, "initial spawn")
				var power: float = fighter.knock_power
				var resist: float = fighter.knock_resist
				fighter.on_eliminated()
				fighter.respawn_at(fighter.global_position)
				t.equal(fighter._duel_compound_budget_enabled, enabled, "respawn retains versioned profile")
				t.near(fighter.knock_power, power, 0.00000001, "respawn cannot stack outgoing normalization")
				t.near(fighter.knock_resist, resist, 0.00000001, "respawn cannot stack resistance normalization")
			scene._start_next_round()
			for fighter in scene.ctx.fighters:
				_check_profile(t, fighter, enabled, "next round")
			if revision >= 0:
				scene.pb_seek(2)
				t.equal(scene.playback_tick, 2, "recorded input seek reaches exact tick")
				scene.pb_seek(0)
				t.equal(scene.playback_tick, 0, "rewind rebuilds original seeded world")
				for fighter in scene.ctx.fighters:
					_check_profile(t, fighter, enabled, "backward seek rebuild")
			scene.teardown()
			scene.queue_free()
			await host.get_tree().process_frame
	# setup remains a full initialization even if a pooled/cached instance had
	# a profile enabled before derived character stats existed.
	var fighter := Fighter.new()
	host.add_child(fighter)
	fighter.health = 17.0
	fighter.set_duel_compound_budget_enabled(true)
	fighter.setup(0, Registry.character("sakhra"))
	t.near(fighter.health, fighter.max_health, 0.00001, "setup initializes health with a pre-enabled profile")
	_check_profile(t, fighter, true, "pre-enabled setup")
	fighter.queue_free()
	await host.get_tree().process_frame


func _check_profile(t: TestHarness, fighter: Fighter, enabled: bool, label: String) -> void:
	t.equal(fighter._duel_compound_budget_enabled, enabled, label + " profile enable follows game and recorded revision")
	var raw_power: float = fighter._duel_budget_base_power
	var raw_resist: float = fighter._duel_budget_base_resist
	var budget: float = (raw_power / fighter._duel_budget_neutral_power) \
		* pow(raw_resist / fighter._duel_budget_neutral_resist, 3.0)
	var scale := pow(clampf(budget, 0.85, 1.15) / budget, 0.25) if enabled else 1.0
	t.near(fighter.knock_power, raw_power * scale, 0.00000001, label + " outgoing profile derives from unscaled authored stats")
	t.near(fighter.knock_resist, raw_resist * scale, 0.00000001, label + " incoming profile derives from unscaled authored stats")
	if not enabled:
		t.equal(fighter.knock_power, raw_power, label + " historical and other games retain raw power exactly")
		t.equal(fighter.knock_resist, raw_resist, label + " historical and other games retain raw resistance exactly")
