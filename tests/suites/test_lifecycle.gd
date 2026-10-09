extends RefCounted
## App lifecycle: backgrounding must flush the save and pause a live match;
## foregrounding must not silently resume one the player was not looking at.
## These are `Platform`'s own documented contracts — this is what proves they
## still hold as the surface around them (mutators, presets, replay) grows.

var _host: Node


func run(t: TestHarness, host: Node) -> void:
	_host = host
	t.suite("lifecycle")
	_background_flushes_and_is_idempotent(t)
	await _match_pauses_on_real_background_signal(t)
	await _teardown_retires_live_match(t)
	await _completion_owner_lifetime(t)


func _completion_owner_lifetime(t: TestHarness) -> void:
	t.test("completion targets survive their caller and are released at teardown")
	var scene: Node = load("res://src/match/match_scene.gd").new()
	_host.add_child(scene)
	var target := _attach_completion_target(scene)
	t.ok(target.get_ref() != null, "match retains its temporary RefCounted callback owner")
	t.ok(scene._on_finished.is_valid(), "callback remains callable after launcher returns")
	if scene._on_finished.is_valid():
		scene._on_finished.call(null)
		t.equal(target.get_ref().calls, 1, "retained callback receives completion")
	scene.teardown()
	t.equal(target.get_ref(), null, "teardown releases callback owner instead of leaking it")
	t.ok(scene._on_finished.is_null(), "retired match has no completion callback")
	scene.queue_free()
	await _host.get_tree().process_frame


func _attach_completion_target(scene: Node) -> WeakRef:
	var target := CompletionTarget.new()
	var config := MatchConfig.build("ring_rumble", _characters(), 0, PlayerConfig.Difficulty.EASY, 78)
	scene.setup({"config": config, "on_finished": Callable(target, "accept")})
	return weakref(target)


class CompletionTarget extends RefCounted:
	var calls := 0

	func accept(_result: MatchResult) -> void:
		calls += 1


func _teardown_retires_live_match(t: TestHarness) -> void:
	t.test("teardown stops live callbacks before draining pools and is idempotent")
	var cfg := MatchConfig.build("ring_rumble", _characters(), 0, PlayerConfig.Difficulty.EASY, 78)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	_host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	for next in [MatchPhase.P.INSTRUCTIONS, MatchPhase.P.COUNTDOWN, MatchPhase.P.PLAYING]:
		scene._set_phase(next)
	scene.powerups.enabled = true
	scene.powerups._spawn_timer = -1.0
	var errors_before := Log.error_count()
	var remaining: float = scene.ctx.time_left
	var elapsed: float = scene._round_elapsed
	scene.teardown()
	t.equal(scene.process_mode, Node.PROCESS_MODE_DISABLED, "retired subtree cannot process while awaiting deletion")
	t.ok(not Pool.has_pool(PowerUpSystem.POOL_KEY), "match pools are drained")
	scene._physics_process(1.0)
	scene._process(1.0)
	await _host.get_tree().physics_frame
	t.equal(scene.ctx.time_left, remaining, "retired match cannot advance its clock")
	t.equal(scene._round_elapsed, elapsed, "retired match cannot simulate another tick")
	t.equal(Log.error_count(), errors_before, "retired match cannot acquire from a drained pool")
	Pool.define("teardown_successor_probe", func(): return Node.new())
	scene.teardown()
	t.ok(Pool.has_pool("teardown_successor_probe"), "repeated teardown cannot drain a successor's pools")
	Pool.drain("teardown_successor_probe")
	scene.queue_free()
	await _host.get_tree().process_frame


func _background_flushes_and_is_idempotent(t: TestHarness) -> void:
	t.test("backgrounding flushes the save exactly once and toggles is_backgrounded")
	var was_backgrounded := Platform.is_backgrounded
	var was_audio_suspended := AudioManager.is_suspended()
	Platform.is_backgrounded = false
	# GDScript lambdas capture outer locals by value, not by reference — an int
	# incremented inside the callable would never be visible out here. A single-
	# element array is a reference type, so the mutation is actually shared.
	var flushes := [0]
	var on_saved := func(): flushes[0] += 1
	SaveSystem.profile_saved.connect(on_saved)
	SaveSystem.mark_dirty("profile")

	Platform._on_background()
	t.ok(Platform.is_backgrounded, "Platform reports backgrounded")
	t.ok(AudioManager.is_suspended(), "audio is suspended on the way out")
	t.equal(flushes[0], 1, "the save was flushed on the way out — iOS may never call back")

	# iOS fires NOTIFICATION_APPLICATION_PAUSED and WM_WINDOW_FOCUS_OUT together;
	# both route to _on_background(). The second must not flush again.
	Platform._on_background()
	t.equal(flushes[0], 1, "a repeated background notification does not flush a second time")

	Platform._on_foreground()
	t.ok(not Platform.is_backgrounded, "Platform reports foregrounded")
	t.ok(not AudioManager.is_suspended(), "audio resumes")

	SaveSystem.profile_saved.disconnect(on_saved)
	Platform.is_backgrounded = was_backgrounded
	AudioManager.set_suspended(was_audio_suspended)


func _characters() -> Array:
	var all := Registry.characters()
	var out: Array = []
	for i in 4:
		out.append(all[i % all.size()].id)
	return out


func _match_pauses_on_real_background_signal(t: TestHarness) -> void:
	t.test("a live match pauses itself on Platform's real background signal, and does not silently resume on foreground")
	var was_backgrounded := Platform.is_backgrounded
	Platform.is_backgrounded = false
	var cfg := MatchConfig.build("ring_rumble", _characters(), 0, PlayerConfig.Difficulty.EASY, 77)
	cfg.duration_override = 30.0
	var script: Script = load("res://src/match/match_scene.gd")
	var scene: Node = script.new()
	_host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	var tree := _host.get_tree()
	var guard := 0
	while not MatchPhase.is_live(scene.phase) and guard < 3000:
		await tree.physics_frame
		guard += 1
	t.ok(MatchPhase.is_live(scene.phase), "the match reached a live phase")

	Platform._on_background()
	await tree.physics_frame
	t.ok(scene._paused, "the live match paused itself off the real Platform signal, not a manual toggle")

	Platform._on_foreground()
	await tree.physics_frame
	t.ok(scene._paused, "coming back to the foreground does not silently resume a match the player was not looking at")

	t.test("match completion preserves interrupted round eligibility")
	var interrupted := MatchResult.make(cfg.minigame_id, cfg.arena_id, [4, 0, 0, 0] as Array[int])
	interrupted.finished_naturally = false
	scene._round_results.clear()
	scene._round_results.append(interrupted)
	scene._aborted = false
	var outcomes: Array[MatchResult] = []
	scene._on_finished = func(result: MatchResult): outcomes.append(result)
	scene._complete_match()
	t.equal(outcomes.size(), 1, "the real completion path delivers one aggregate")
	if outcomes.size() == 1:
		t.ok(not outcomes[0].finished_naturally, "the scene cannot turn an interrupted round into a rewardable match")
	t.equal(scene.phase, MatchPhase.P.DONE, "interrupted result still completes cleanup flow")

	scene.teardown()
	scene.queue_free()
	await tree.process_frame
	Platform.is_backgrounded = was_backgrounded
