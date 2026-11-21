extends RefCounted

const Daily = preload("res://src/progression/daily_challenge.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("daily start to natural results")
	var original := SaveSystem.profile().duplicate(true)
	var original_progress := Progression._p.duplicate(true)
	var owner := SaveSystem.create_profile("Daily Flow Owner")
	var other := SaveSystem.create_profile("Daily Flow Other")
	SaveSystem.switch_profile(owner)
	await SceneRouter.go_to("daily", {}, false, 0)
	var screen: Control = SceneRouter.current_node
	# Freeze this regression's UTC schedule, not the simulation. A future daily
	# race needs driving inputs; an idle human is not a valid race finisher.
	# Actual UTC selection is covered separately by test_daily_challenge.
	screen._plan = Daily.plan("20261009")
	var setup: Dictionary = screen._plan.duplicate(true)
	var original_screen := weakref(screen)
	screen.first_focus.pressed.emit()
	screen.first_focus.pressed.emit()
	var loading_deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < loading_deadline:
		if SceneRouter.current_id == "match":
			break
		await host.get_tree().physics_frame
	t.equal(SceneRouter.current_id, "match", "start opens the real match")
	t.equal(Daily.record(owner, setup).get("attempts", 0), 1, "double activation counts one attempt")
	if SceneRouter.current_id == "match":
		var match_scene = SceneRouter.current_node
		t.ok(match_scene._on_finished.is_valid(), "completion callback survives the launching stack")
		t.equal(match_scene.config.seed, setup.seed, "loaded match uses preview seed")
		t.equal(match_scene.config.players[0].local_profile_id, owner, "loaded match captures original owner")
		SaveSystem.switch_profile(other)
		# Let the actual simulation and its lifecycle finish; no score, timer,
		# winner, round count or callback is injected by this test.
		for tick in 60000:
			if SceneRouter.current_id == "results":
				break
			var key := InputEventKey.new()
			key.keycode = KEY_F
			key.physical_keycode = KEY_F
			key.pressed = match_scene.phase == MatchPhase.P.INSTRUCTIONS and tick % 30 == 0
			Input.parse_input_event(key)
			await host.get_tree().physics_frame
		t.equal(SceneRouter.current_id, "results", "natural completion reaches results")
		if SceneRouter.current_id == "results":
			var result: MatchResult = SceneRouter.current_node.args.result
			print("DAILY_FLOW_RESULT setup=%s game=%s arena=%s natural=%s duration=%s scores=%s places=%s owner_record=%s" % [JSON.stringify(setup), result.minigame_id, result.arena_id, result.finished_naturally, result.duration, result.scores, result.places, JSON.stringify(Daily.record(owner, setup))])
			t.ok(result.finished_naturally, "result is from natural completion")
			t.equal(result.minigame_id, setup.game, "results match selected challenge")
			t.equal(Daily.record(owner, setup).get("completed", 0), 1, "completion survives freed menu")
			t.equal(Daily.record(other, setup).get("attempts", 0), 0, "active profile cannot take over daily records")
			t.equal(Daily.claimed(owner, setup.key), result.winners().size() == 1 and result.winner_slot() == 0, "claim matches actual unique victory")
			t.ok(not Daily.claimed(other, setup.key), "other profile gets no daily claim")
	await SceneRouter.go_to("main_menu", {}, false, 0)
	await host.get_tree().process_frame
	t.equal(original_screen.get_ref(), null, "original daily screen was freed")
	t.equal(SceneRouter.holder.get_child_count(), 1, "flow leaves one routed screen")
	SaveSystem.set_profile(original)
	Progression._p = original_progress
