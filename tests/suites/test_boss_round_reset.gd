extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("boss round reset")
	for id in ["boss_forge", "boss_colossus", "boss_dreadnought", "boss_sovereign"]:
		t.test("%s restores defeated and interrupted rounds" % id)
		var scene: Node = load("res://src/match/match_scene.gd").new()
		host.add_child(scene)
		scene.setup({"config": MatchConfig.build(id, ["fanoos", "mowja", "ramla", "nabta"], 0, 4, 119), "on_finished": func(_r): pass})
		scene.set_physics_process(false)
		var game: Node = scene.controller
		var spawn: Transform3D = game.boss_node.global_transform
		var body_id: int = game.boss_node.get_instance_id()
		var body_children: int = game.boss_node.get_child_count()
		for round in 3:
			var old_nodes: Array = _populate_old_round(game, id)
			game.fire_shot(game.boss_node.global_position, Vector3.FORWARD, 10.0, 12.0, 30.0)
			old_nodes.append(game._shots.back())
			var probe := {"landed": false}
			game.telegraph(Vector3.ZERO, 2.0, 0.1, func(_pos, _radius): probe.landed = true)
			old_nodes.append(game._telegraphs.back().node)
			game.boss_node.global_position += Vector3(7, 0, 3)
			game.boss_node.rotation.y = 1.2
			if round != 1:
				game.damage_boss(game.boss_max_health, 0)
				t.ok(game.boss_defeated and not game.boss_node.visible, "real damage API hides defeated boss")
				t.ok(scene.ctx.early_finish, "defeat requests round completion")
			else:
				game.damage_boss(game.boss_max_health * 0.2, 0)
				game._hit_flash = 0.1
				t.ok(not game.boss_defeated, "interrupted round keeps boss alive before transition")
			scene._start_next_round()
			t.equal(scene._round_index, round + 1, "actual match transition advances round")
			t.ok(game.boss_node.visible, "next-round boss is visible")
			t.ok(game.boss_node.global_transform.is_equal_approx(spawn), "next round restores authored boss spawn and rotation")
			t.equal(game.boss_node.get_instance_id(), body_id, "body is reused, not duplicated")
			t.equal(game.boss_health, game.boss_max_health, "next round restores full health")
			t.equal(game.phase, 0, "next round restores first phase")
			t.ok(not game.boss_defeated and not scene.ctx.early_finish, "next round clears finish state")
			t.near(game._hit_flash, 0.0, 0.0001, "next round has no stale hit flash")
			t.empty(game._shots, "old boss projectiles are discarded")
			t.empty(game._telegraphs, "old warning callbacks are discarded")
			t.equal(Array(scene.ctx.scores), [0, 0, 0, 0], "round scores do not leak")
			_check_specific(t, game, id)
			game._tick_telegraphs(1.0)
			t.ok(not probe.landed, "cancelled prior-round callback never lands")
			await host.get_tree().process_frame
			for node in old_nodes:
				t.ok(not is_instance_valid(node), "old-round object is freed after deferred cleanup")
			var expected_children := body_children + (1 if id == "boss_sovereign" else 0)
			t.equal(game.boss_node.get_child_count(), expected_children, "repeated rounds do not accumulate boss parts")
			_check_opening(t, game, id)
			# Resetting twice must not recreate objects or consume the opening timers.
			game.on_round_start()
			_check_specific(t, game, id)
		scene.teardown()
		scene.queue_free()
		await host.get_tree().process_frame
		await host.get_tree().process_frame


func _populate_old_round(game: Node, id: String) -> Array:
	var nodes: Array = []
	match id:
		"boss_forge":
			game._lob_crate()
			game._spawn_slag(game.boss_node.global_position + Vector3(4, 0, 0), 0)
			nodes.append(game._crates.back())
			nodes.append(game._slag.back().node)
			game._crate_timer = 0.01
			game._stomp_timer = 0.01
			game._intake.rotation.z = 2.0
		"boss_colossus":
			game._open_crater(Vector3(4, 0, 0), 3.0)
			nodes.append(game._craters.back().node)
			game._slam_timer = 0.01
			game._sweep_timer = 0.01
			game._exposed = 1.0
			game._hit_this_window[0] = true
			game._arm.rotation.y = 2.0
			game._fist.position = Vector3(2, -3, 1)
			game._fist.scale = Vector3.ONE * 1.15
		"boss_dreadnought":
			game._drop_mine()
			nodes.append(game._mines.back().node)
			game._facing = 1.2
			game._aim_at = 2
			game._shell_timer = 0.01
			game._mine_timer = 0.01
			game._spin_timer = 0.01
			game._vent_cd[0] = 1.0
		"boss_sovereign":
			game._raise_shield()
			game._throw_orbs()
			for orb in game._orbs: nodes.append(orb.node)
			game._lunge_timer = 0.01
			game._orb_timer = 0.01
			game._collapse_timer = 0.01
			game._recover = 1.0
			game._hit_window[0] = true
			game._core.scale = Vector3.ONE * 1.08
	return nodes


func _check_opening(t: TestHarness, game: Node, id: String) -> void:
	var fighter: Fighter = game.ctx.fighter(0)
	match id:
		"boss_forge":
			game.tick(2.01)
			t.equal(game._crates.size(), 1, "new forge round spawns its first usable crate")
			fighter.global_position = game._crates[0].global_position + Vector3(0, 0, 1)
			fighter._attack_time = 0.2
			game._check_feeding()
			t.empty(game._crates, "real swing breaks the new-round crate")
			t.equal(game._slag.size(), 1, "new-round crate produces usable slag")
			game._slag[0].node.global_position = game._intake.global_position
			game._tick_slag(0.0)
			t.near(game.boss_health, game.boss_max_health - game.SLAG_DAMAGE, 0.001, "new-round slag damages forge through intake")
		"boss_colossus":
			game.tick(2.51)
			t.equal(game._telegraphs.size(), 1, "new colossus round announces its first slam")
			game._tick_telegraphs(1.3)
			t.greater(game._exposed, 0.0, "new slam exposes the fist")
			fighter.global_position = game._fist.global_position
			fighter._attack_time = 0.2
			game._check_arm_hits()
			t.near(game.boss_health, game.boss_max_health - game.ARM_DAMAGE, 0.001, "new-round fist accepts a fresh player's swing")
		"boss_dreadnought":
			game.tick(2.01)
			t.equal(game._shots.size(), 1, "new dreadnought round fires its first shell")
			fighter.global_position = game._vent.global_position
			fighter._attack_time = 0.2
			game._check_vent_hits(0.01)
			t.near(game.boss_health, game.boss_max_health - game.VENT_DAMAGE, 0.001, "new-round rear vent accepts a fresh swing")
		"boss_sovereign":
			game.tick(2.01)
			t.equal(game._telegraphs.size(), 1, "new sovereign round announces its first lunge")
			game._tick_telegraphs(1.4)
			t.greater(game._recover, 0.0, "new lunge exposes sovereign core")
			fighter.global_position = game._core.global_position
			fighter._attack_time = 0.2
			game._check_core_hits()
			t.near(game.boss_health, game.boss_max_health - game.CORE_DAMAGE, 0.001, "new-round core accepts a fresh swing")
	fighter._attack_time = 0.0


func _check_specific(t: TestHarness, game: Node, id: String) -> void:
	match id:
		"boss_forge":
			t.empty(game._crates, "forge crates cleared")
			t.empty(game._slag, "forge slag cleared")
			t.near(game._crate_timer, 2.0, 0.0001, "forge initial crate delay restored")
			t.near(game._stomp_timer, game.STOMP_PERIOD, 0.0001, "forge stomp delay restored")
			t.ok(game._intake.rotation.is_equal_approx(Vector3(PI * 0.5, 0, 0)), "forge intake rotation restored")
		"boss_colossus":
			t.empty(game._craters, "colossus old holes cleared")
			t.empty(game._hit_this_window, "colossus hit allowance cleared")
			t.near(game._slam_timer, 2.5, 0.0001, "colossus initial slam delay restored")
			t.near(game._sweep_timer, game.SWEEP_PERIOD, 0.0001, "colossus sweep delay restored")
			t.near(game._exposed, 0.0, 0.0001, "colossus old weak-point exposure cleared")
			t.ok(game._arm.rotation.is_equal_approx(Vector3.ZERO), "colossus arm rotation restored")
			t.ok(game._fist.position.is_equal_approx(Vector3(9.2, 0, 0)), "colossus fist rest position restored")
			t.ok(game._fist.scale.is_equal_approx(Vector3.ONE), "colossus fist scale restored")
		"boss_dreadnought":
			t.empty(game._mines, "dreadnought mines cleared")
			t.empty(game._vent_cd, "dreadnought prior hit cooldowns cleared")
			t.equal(game._aim_at, -1, "dreadnought old target cleared")
			t.near(game._facing, 0.0, 0.0001, "dreadnought facing restored")
			t.near(game._shell_timer, 2.0, 0.0001, "dreadnought initial shell delay restored")
			t.near(game._mine_timer, game.MINE_PERIOD, 0.0001, "dreadnought mine delay restored")
			t.near(game._spin_timer, game.SPIN_PERIOD, 0.0001, "dreadnought spin delay restored")
		"boss_sovereign":
			t.empty(game._orbs, "sovereign orbs cleared")
			t.empty(game._hit_window, "sovereign prior hit allowance cleared")
			t.ok(not game._shielded and not game._shield.visible, "sovereign shield cleared and hidden")
			t.near(game._recover, 0.0, 0.0001, "sovereign prior recovery window cleared")
			t.near(game._lunge_timer, 2.0, 0.0001, "sovereign initial lunge delay restored")
			t.near(game._orb_timer, game.ORB_PERIOD, 0.0001, "sovereign orb delay restored")
			t.near(game._collapse_timer, game.COLLAPSE_PERIOD, 0.0001, "sovereign collapse delay restored")
			t.ok(game._core.scale.is_equal_approx(Vector3.ONE), "sovereign core scale restored")
