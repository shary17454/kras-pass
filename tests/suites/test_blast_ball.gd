extends RefCounted

class ContactProbe extends GameBall:
	var checks := 0
	func _check_contacts() -> void:
		checks += 1


func run(t: TestHarness, host: Node) -> void:
	t.suite("blast ball lifecycle")
	var ball := GameBall.new()
	host.add_child(ball)
	ball.configure(Color.RED, 0.62, false, true)
	ball.fuse_max = 0.1
	ball.launch(Vector3(0, 0.9, 0), Vector3.RIGHT, 7)
	var events := [0]
	ball.exploded.connect(func(_ball, _position): events[0] += 1)
	ball.tick(0.2)
	ball.tick(0.2)
	t.equal(events[0], 1, "one explosion per launch even without a rearming listener")
	ball.launch(Vector3(0, 0.9, 0), Vector3.RIGHT, 7)
	t.equal(ball._label.text, "0.1", "launch immediately restores visible fuse")
	ball.tick(0.2)
	t.equal(events[0], 2, "rearmed ball can explode again")
	ball.queue_free()
	await host.get_tree().process_frame
	var probe := ContactProbe.new()
	host.add_child(probe)
	probe.explosive = true
	probe.fuse_max = 0.1
	probe.launch(Vector3(0, 0.9, 0), Vector3.RIGHT, 7)
	probe.exploded.connect(func(_ball, _position): probe.launch(Vector3(4, 0.9, 0), Vector3.FORWARD, 7))
	probe.tick(0.2)
	t.equal(probe.checks, 0, "rearming listener cannot apply stale overlap contacts to new ball")
	t.ok(not probe.detonated, "listener rearm clears detonation latch")
	probe.tick(0.01)
	t.equal(probe.checks, 1, "new launch checks contacts on its next tick")
	probe.queue_free()
	await host.get_tree().process_frame
	var cfg := MatchConfig.build("blast_ball", ["fanoos", "mowja", "ramla", "nabta"], 0, 2, 104)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": cfg, "on_finished": func(_r): pass})
	scene.set_physics_process(false)
	var game = scene.controller
	var baseline := Balance.num("tuning", "ball.explosive_fuse", 5.0)
	game.on_sudden_death()
	game.ball.fuse = 0.2
	game.ball.last_toucher = 2
	game.ball._touch_cooldown[2] = 0.25
	game.ball.global_position = Vector3(3, 0.9, 2)
	var generation: int = game.ball.launch_generation
	game.on_round_start()
	t.near(game._fuse_max, baseline, 0.0001, "new round removes sudden death fuse override")
	t.near(game.ball.fuse, baseline, 0.0001, "new round has a complete fuse")
	t.equal(game.ball.last_toucher, -1, "new round has no previous attacker credit")
	t.ok(game.ball._touch_cooldown.is_empty(), "new round clears contact cooldowns")
	t.ok(game.ball.launch_generation > generation, "new round is a new launch generation")
	t.ok(game.ball.global_position.is_equal_approx(scene.arena.global_position + Vector3(0, 0.9, 0)), "new round returns ball to centre")
	for slot in scene.ctx.player_count():
		scene.ctx.alive[slot] = slot == 0
	scene.ctx.fighter(0).global_position = Vector3(0, 0.9, -100)
	var headings: Array[Vector3] = []
	for fps in [30, 60, 120]:
		game.ball.launch(Vector3(0, 0.9, 0), Vector3.RIGHT, 7)
		for tick in fps / 2:
			game.ball.global_position = Vector3(0, 0.9, 0)
			game.tick(1.0 / fps)
		headings.append(game.ball.velocity.normalized())
	t.ok(headings[0].angle_to(headings[1]) < 0.03, "homing strength remains comparable at 30 and 60 Hz")
	t.ok(headings[2].angle_to(headings[1]) < 0.03, "homing strength remains comparable at 60 and 120 Hz")
	scene.teardown()
	scene.queue_free()
	await host.get_tree().process_frame
