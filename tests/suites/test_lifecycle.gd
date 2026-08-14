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

	scene.teardown()
	scene.queue_free()
	await tree.process_frame
	Platform.is_backgrounded = was_backgrounded
