extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("routed natural tournament flow")
	var original := SaveSystem.profile().duplicate(true)
	var original_progress := Progression._p.duplicate(true)
	var owner := SaveSystem.create_profile("Tournament Flow")
	SaveSystem.switch_profile(owner)
	for human_count in range(1, 5):
		await _case(t, host, owner, human_count)
	await _case(t, host, owner, 4, true)
	SaveSystem.set_profile(original)
	Progression._p = original_progress


func _case(t: TestHarness, host: Node, owner: String, human_count: int, tie_schedule := false) -> void:
	t.test("%d humans and %d bots through routed tournament%s" % [human_count, 4 - human_count, " with idle reaction ties" if tie_schedule else ""])
	await SceneRouter.go_to("main_menu", {}, false, 0)
	var session_ref := _launch(owner, human_count, tie_schedule)
	var finished := false
	var completed_games := 0
	var expected_points: Array[int] = [0, 0, 0, 0]
	for game in 3 + TournamentSession.MAX_TIEBREAKS:
		await _wait_for(host, "match", 30000)
		t.equal(SceneRouter.current_id, "match", "next action opens a match")
		if SceneRouter.current_id != "match":
			break
		var match_scene = SceneRouter.current_node
		t.ok(match_scene._on_finished.is_valid(), "temporary tournament owner survives launching screen")
		if game < 3:
			t.equal(match_scene.config.players.filter(func(player): return player.is_human).size(), human_count, "local human roster remains assigned")
		for tick in 60000:
			if SceneRouter.current_id != "match":
				break
			var key := InputEventKey.new()
			key.keycode = KEY_F
			key.physical_keycode = KEY_F
			key.pressed = match_scene.phase == MatchPhase.P.INSTRUCTIONS and tick % 30 == 0
			Input.parse_input_event(key)
			await host.get_tree().physics_frame
		t.equal(SceneRouter.current_id, "standings", "natural completion returns to tournament standings")
		if SceneRouter.current_id != "standings":
			break
		var standings = SceneRouter.current_node
		t.ok(standings.last.finished_naturally, "round result was not injected or aborted")
		t.ok(session_ref.get_ref() != null, "same tournament session reaches standings")
		t.equal(standings.session.get_instance_id(), session_ref.get_ref().get_instance_id(), "standings retain the original session")
		t.equal(standings.session.rows().size(), 4, "all four standings remain present")
		for slot in 4:
			expected_points[slot] += standings.session.last_awards[slot]
		t.equal(standings.session.points, expected_points, "total points equal displayed round awards")
		completed_games += 1
		print("TOURNAMENT_FLOW game=%s index=%d points=%s complete=%s" % [standings.last.minigame_id, standings.session.index, standings.session.points, standings.session.is_complete()])
		if standings.session.is_complete():
			finished = true
			t.equal(standings.session.index, 3, "all three scheduled games completed")
			t.ok(standings.session.recorded, "tournament completion recorded")
			t.ok(standings.session.champion() >= 0 or not standings.session.shared_champions.is_empty(), "champion or explicit shared cup exists")
			if tie_schedule:
				t.equal(standings.session.tiebreak_attempts, TournamentSession.MAX_TIEBREAKS, "naturally tied reaction matches respect the decider limit")
				t.equal(standings.session.champion(), -1, "unresolved tie does not invent a champion")
				t.equal(standings.session.shared_champions, [0, 1, 2, 3] as Array[int], "all tied players share the cup")
			t.equal(SaveSystem.shared_branch(TournamentSession.SAVE_BRANCH), {}, "completed checkpoint is cleared")
			t.ok(_has_podium(standings), "champion screen contains the actual podium")
			var quit := _button(standings, Loc.t("results.quit"))
			t.ok(quit != null, "champion screen has a return action")
			if quit != null:
				quit.pressed.emit()
			break
		t.equal(standings.first_focus.text, Loc.t("tournament.next_game"), "between-round primary action is Next Game")
		standings.first_focus.pressed.emit()
	await _wait_for(host, "main_menu", 30000)
	t.ok(finished, "tournament reaches its ending within the existing tie limit")
	t.ok(completed_games >= 3, "at least three natural matches were played")
	if SceneRouter.current_id != "main_menu":
		await SceneRouter.go_to("main_menu", {}, false, 0)
	for frame in 3:
		await host.get_tree().process_frame
	t.equal(SceneRouter.current_id, "main_menu", "champion return reaches main menu")
	t.equal(SceneRouter.holder.get_child_count(), 1, "tournament flow leaves one screen")
	t.equal(session_ref.get_ref(), null, "completed session is released after leaving its result screen")


func _launch(owner: String, human_count: int, tie_schedule: bool) -> WeakRef:
	var players := MatchConfig.build("gem_grab", ["nabta", "sakhra", "fanous", "ramla"], human_count, PlayerConfig.Difficulty.MEDIUM, 1337).players
	players[0].local_profile_id = owner
	for slot in range(1, human_count):
		players[slot].device_type = 0 if slot == 1 else 2
		players[slot].device_id = 1 if slot == 1 else -1
	var session := TournamentSession.new()
	var games: Array[String] = []
	games.assign(["quick_draw", "quick_draw", "quick_draw"] if tie_schedule else ["gem_grab", "ring_rumble", "quick_draw"])
	session.setup(players, games, 1337)
	session.owner_profile = owner
	session.checkpoint()
	SceneRouter.start_match(session.next_config(), Callable(session, "on_match_finished"))
	return weakref(session)


func _wait_for(host: Node, id: String, timeout: int) -> void:
	var deadline := Time.get_ticks_msec() + timeout
	while SceneRouter.current_id != id and Time.get_ticks_msec() < deadline:
		await host.get_tree().physics_frame


func _button(node: Node, text: String) -> Button:
	if node is Button and node.text == text:
		return node
	for child in node.get_children():
		var found := _button(child, text)
		if found != null:
			return found
	return null


func _has_podium(node: Node) -> bool:
	if node is TournamentPodium:
		return true
	for child in node.get_children():
		if _has_podium(child):
			return true
	return false
