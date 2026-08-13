extends RefCounted
## Same-tick races the match state machine has to survive without ending the
## match twice, pausing a phase that is already gone, or leaking a second
## pause menu — the exact scenarios named in the project's own engineering
## constraints, not hypothetical ones.

var _host: Node


func run(t: TestHarness, host: Node) -> void:
	_host = host
	t.suite("race conditions")
	await _timer_zero_and_ko_same_tick(t)
	await _disconnect_at_round_end(t)
	await _sudden_death_and_player_leave(t)
	await _pause_and_disconnect_same_tick(t)


func _characters() -> Array:
	var all := Registry.characters()
	var out: Array = []
	for i in 4:
		out.append(all[i % all.size()].id)
	return out


func _spawn(game_id: String, humans: int = 0) -> Dictionary:
	var cfg := MatchConfig.build(game_id, _characters(), humans, PlayerConfig.Difficulty.EASY, 4242)
	cfg.duration_override = 30.0
	var script: Script = load("res://src/match/match_scene.gd")
	var scene: Node = script.new()
	_host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	return {"scene": scene, "cfg": cfg}


func _wait_live(scene: Node) -> void:
	var tree := _host.get_tree()
	var guard := 0
	while not MatchPhase.is_live(scene.phase) and guard < 3000:
		await tree.physics_frame
		guard += 1


func _teardown(scene: Node) -> void:
	scene.teardown()
	scene.queue_free()
	await _host.get_tree().process_frame


## ring_rumble scores by SURVIVAL/LIVES, so is_round_over() is
## `alive_count() <= 1` — the same shape as the clock running out. Forcing
## both true for one call to `_evaluate_end()` is exactly the frame the KO and
## the buzzer land together.
func _timer_zero_and_ko_same_tick(t: TestHarness) -> void:
	t.test("timer hitting zero and a KO landing on the same tick end the match exactly once")
	var spawned := _spawn("ring_rumble")
	var scene: Node = spawned["scene"]
	await _wait_live(scene)
	t.ok(MatchPhase.is_live(scene.phase), "match reached a live phase")
	var warn_before := Log.count(Log.Level.WARN)
	scene.ctx.time_left = 0.0
	for i in range(1, scene.ctx.fighters.size()):
		scene.ctx.eliminate(i)
	t.equal(scene.ctx.alive_count(), 1, "only one fighter is left standing, forcing is_round_over() true")
	scene._evaluate_end(1.0 / 60.0)
	t.equal(scene.phase, MatchPhase.P.FINISH, "the KO decides it — the match does not fall through to sudden death")
	# A second evaluation in the same tick — as could happen if two systems
	# both react to the same frame — must not be a second, illegal transition.
	scene._evaluate_end(1.0 / 60.0)
	t.equal(scene.phase, MatchPhase.P.FINISH, "re-evaluating the same tick does not move the phase again")
	t.equal(Log.count(Log.Level.WARN), warn_before, "no illegal-transition warning was logged")
	await _teardown(scene)


func _disconnect_at_round_end(t: TestHarness) -> void:
	t.test("a controller disconnecting the instant the round ends does not force a pause into a dead phase")
	var spawned := _spawn("ring_rumble", 1)
	var scene: Node = spawned["scene"]
	var cfg: MatchConfig = spawned["cfg"]
	cfg.players[0].device_type = 1
	cfg.players[0].device_id = 3   # a pad that is not connected
	await _wait_live(scene)
	# End the round first, in the same tick the device is lost — a player
	# yanking their controller right as the buzzer sounds.
	scene.ctx.time_left = 0.0
	scene.ctx.early_finish = true
	scene._evaluate_end(1.0 / 60.0)
	t.equal(scene.phase, MatchPhase.P.FINISH, "the round already ended")
	EventBus.player_device_lost.emit(0)
	await scene.get_tree().physics_frame
	t.ok(not scene._paused, "a device lost after the round is over does not pause a match that already finished")
	await _teardown(scene)


func _sudden_death_and_player_leave(t: TestHarness) -> void:
	t.test("a device lost during sudden death pauses just like it does during regular play")
	var spawned := _spawn("ring_rumble", 1)
	var scene: Node = spawned["scene"]
	var cfg: MatchConfig = spawned["cfg"]
	cfg.players[0].device_type = 1
	cfg.players[0].device_id = 3
	await _wait_live(scene)
	scene._set_phase(MatchPhase.P.SUDDEN_DEATH)
	t.equal(scene.phase, MatchPhase.P.SUDDEN_DEATH, "the scene entered sudden death")
	EventBus.player_device_lost.emit(0)
	await scene.get_tree().physics_frame
	t.ok(scene._paused, "losing the human's device during sudden death still pauses the match")
	await _teardown(scene)


func _pause_and_disconnect_same_tick(t: TestHarness) -> void:
	t.test("a manual pause and a device loss landing on the same tick do not leave two pause menus")
	var spawned := _spawn("ring_rumble", 1)
	var scene: Node = spawned["scene"]
	var cfg: MatchConfig = spawned["cfg"]
	cfg.players[0].device_type = 1
	cfg.players[0].device_id = 3
	await _wait_live(scene)
	scene._toggle_pause()
	EventBus.player_device_lost.emit(0)
	await scene.get_tree().physics_frame
	t.ok(scene._paused, "the match is paused")
	var menus := 0
	for c in scene.get_children():
		if c is CanvasLayer and c.layer == 40:
			menus += 1
	t.equal(menus, 1, "exactly one pause menu exists, not a stacked second one from the disconnect")
	await _teardown(scene)
