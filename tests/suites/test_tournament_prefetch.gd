extends RefCounted

const Preparation = preload("res://src/match/match_resource_preparation.gd")

class PendingPreparation extends "res://src/match/match_resource_preparation.gd":
	var state := ResourceLoader.THREAD_LOAD_IN_PROGRESS
	var stats := {"requests": 0, "takes": 0}
	func _request(_path: String) -> Error:
		stats.requests += 1
		return OK
	func _status(_path: String) -> int:
		return state
	func _take(_path: String) -> Resource:
		stats.takes += 1
		return Resource.new()

class PendingRouter extends "res://src/core/scene_router.gd":
	func _new_prefetch_job() -> Node:
		return PendingPreparation.new()

class CountingPreparation extends "res://src/match/match_resource_preparation.gd":
	var requests := 0
	func _request(path: String) -> Error:
		requests += 1
		return super._request(path)


func run(t: TestHarness, host: Node) -> void:
	t.suite("one-round tournament resource prefetch")
	var tree := host.get_tree()
	var roster := PartyRoster.last_players()
	var session := TournamentSession.new()
	session.setup(roster, ["ring_rumble", "gem_grab", "quick_draw"], 227)
	session.chaos = true
	session.match_rules = {"round_seconds": 45, "race_laps": 3}
	var before := session.to_dict().duplicate(true)
	var preview := session.following_config()
	t.equal(preview.minigame_id, "gem_grab", "preview selects only the immediately following game")
	t.equal(session.to_dict(), before, "preview never advances scores, saves or random schedule state")
	session.index = 1
	var actual := session.next_config()
	for property in preview.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE and int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			t.equal(preview.get(property.name), actual.get(property.name), "preview matches eventual config field: " + String(property.name))
	session.index = 2
	t.ok(session.following_config() == null, "last game does not speculate about a result-dependent final")
	session.index = 3
	session.tiebreak_slots.assign([0, 2])
	t.equal(session.next_config().minigame_id, "quick_draw", "existing decider config remains valid at end of schedule")
	t.ok(session.following_config() == null, "tie attempts do not preload an unrelated scheduled game")
	session.tiebreak_slots.clear()
	t.ok(session.following_config() == null, "completed session holds no future plan")
	var cfg := MatchConfig.build("ring_rumble", ["nabta", "sakhra", "barq", "turs"], 1, 1, 12)
	cfg.context = MatchConfig.Context.TOURNAMENT
	var pending := PendingRouter.new()
	host.add_child(pending)
	t.ok(pending.prefetch_match(cfg), "background preparation begins without awaiting completion")
	var bank: PendingPreparation = pending._prefetch_job
	var stats: Dictionary = bank.stats
	t.equal(stats.requests, 1, "only one threaded resource request is outstanding")
	t.ok(pending.prefetch_match(cfg), "identical plans coalesce")
	t.ok(pending._prefetch_job == bank, "coalescing preserves one bank")
	t.equal(stats.requests, 1, "coalescing does not request the resource twice")
	pending.clear_match_prefetch()
	await tree.process_frame
	await tree.process_frame
	t.equal(stats.takes, 0, "cancellation never retrieves an active worker")
	t.equal(stats.requests, 1, "cancellation stops before any following path is requested")
	bank.state = ResourceLoader.THREAD_LOAD_LOADED
	await tree.process_frame
	await tree.process_frame
	t.equal(stats.takes, 1, "cancelled worker is drained once after completion")
	t.ok(not is_instance_valid(bank), "cancelled bank is removed after safe drain")
	t.ok(pending._prefetch_job == null and pending._prefetch_paths.is_empty(), "cancelled plan retains no resources")
	t.ok(pending.prefetch_match(cfg), "a new plan can start after cancellation")
	bank = pending._prefetch_job
	bank.state = ResourceLoader.THREAD_LOAD_LOADED
	var adopted := CountingPreparation.new()
	pending.add_child(adopted)
	t.ok(await pending._prepare_match(adopted, cfg), "a fast next-game press waits for the existing worker")
	t.equal(adopted.requests, 0, "transition does not start duplicate native requests")
	t.equal(adopted.resources.size(), Preparation.paths_for(cfg).size(), "existing bank is transferred into the transition")
	t.ok(pending._prefetch_job == null, "transferred resources are not permanently cached")
	adopted.release()
	await tree.process_frame
	pending.queue_free()
	await tree.process_frame
	var router: Node = load("res://src/core/scene_router.gd").new()
	host.add_child(router)
	t.ok(router.prefetch_match(cfg), "real Godot threaded preload starts")
	var real_bank: Node = router._prefetch_job
	var real_preparation := CountingPreparation.new()
	router.add_child(real_preparation)
	t.ok(await router._prepare_match(real_preparation, cfg), "actual threaded resources are ready for the transition")
	t.equal(real_preparation.requests, 0, "real ready resources are reused, not requested again")
	t.equal(real_preparation.resources.size(), 2, "simple following game does not preload natural worlds")
	await tree.process_frame
	t.ok(not is_instance_valid(real_bank), "old real bank is released after resource handoff")
	t.ok(not real_preparation.resources.is_empty(), "transition owns strong references after old bank release")
	real_preparation.release()
	await tree.process_frame
	t.ok(router.prefetch_match(cfg), "another tournament can prepare its next round")
	t.ok(await router.go_to("main_menu", {}, false, 0.0), "leaving the party returns to the real main menu")
	t.ok(router._prefetch_job == null and router._prefetch_paths.is_empty(), "leaving the party cancels its future resource plan")
	await tree.process_frame
	await tree.process_frame
	cfg.context = MatchConfig.Context.ONLINE
	t.ok(not router.prefetch_match(cfg), "future online arenas are not guessed locally")
	router.queue_free()
	await tree.process_frame
	await _real_party_flow(t, host)


func _real_party_flow(t: TestHarness, host: Node) -> void:
	var tree := host.get_tree()
	t.ok(SceneRouter._prefetch_job == null, "real party flow starts without another screen's resource bank")
	if SceneRouter._prefetch_job != null:
		return
	var saved := [SceneRouter.holder, SceneRouter.current_node, SceneRouter.current_id,
		SceneRouter._stack.duplicate(true), SceneRouter._busy]
	var checkpoint = SaveSystem.shared_branch(TournamentSession.SAVE_BRANCH, {}).duplicate(true)
	var isolated_holder := Control.new()
	host.add_child(isolated_holder)
	SceneRouter.holder = isolated_holder
	SceneRouter.current_node = null
	SceneRouter.current_id = ""
	SceneRouter._stack.clear()
	SceneRouter._busy = false
	var session := TournamentSession.new()
	session.setup(PartyRoster.last_players(), ["ring_rumble", "gem_grab"], 552)
	await SceneRouter.start_match(session.next_config(), Callable(session, "on_match_finished"))
	var match_scene: Node = SceneRouter.current_node
	t.equal(match_scene.config.minigame_id, "ring_rumble", "actual party opens its first mini-game")
	t.equal(match_scene._next_match_config.minigame_id, "gem_grab", "session supplies the next resource plan through the real entry point")
	t.ok(SceneRouter._prefetch_job == null, "gameplay does not compete with background asset preparation")
	match_scene._set_phase(MatchPhase.P.INSTRUCTIONS)
	match_scene._set_phase(MatchPhase.P.COUNTDOWN)
	match_scene._set_phase(MatchPhase.P.PLAYING)
	match_scene._set_phase(MatchPhase.P.FINISH)
	await tree.process_frame
	await tree.process_frame
	t.ok(SceneRouter._prefetch_job != null, "last-round finish starts preparing the following game")
	var future_bank: Node = SceneRouter._prefetch_job
	match_scene._set_phase(MatchPhase.P.RESULTS)
	for frame in 100:
		if SceneRouter.current_id == "standings" and not SceneRouter._busy:
			break
		await tree.process_frame
	t.equal(SceneRouter.current_id, "standings", "actual result callback opens tournament standings")
	t.equal(session.index, 1, "only the recorded result advances the schedule")
	t.ok(SceneRouter._prefetch_job == future_bank, "standings reuse the same confirmed next-game bank")
	await SceneRouter.start_match(session.next_config(), Callable(session, "on_match_finished"))
	t.equal(SceneRouter.current_node.config.minigame_id, "gem_grab", "actual next-game transition consumes the prepared resources")
	t.ok(SceneRouter._prefetch_job == null, "transition does not retain the whole tournament")
	t.ok(SceneRouter.current_node._next_match_config == null, "last scheduled game has no speculative successor")
	var stale := Node.new()
	host.add_child(stale)
	t.ok(not SceneRouter.prefetch_from_screen(stale, session.next_config()), "a stale deferred screen cannot create a new bank")
	await SceneRouter.go_to("main_menu", {}, false, 0.0)
	t.ok(SceneRouter._prefetch_job == null, "exiting actual party play leaves no future resource bank")
	if is_instance_valid(SceneRouter.current_node):
		SceneRouter.current_node.queue_free()
	SceneRouter.holder = saved[0]
	SceneRouter.current_node = saved[1]
	SceneRouter.current_id = saved[2]
	SceneRouter._stack.assign(saved[3])
	SceneRouter._busy = saved[4]
	SaveSystem.set_shared_branch(TournamentSession.SAVE_BRANCH, checkpoint)
	SaveSystem.flush()
	stale.queue_free()
	isolated_holder.queue_free()
	await tree.process_frame
