extends RefCounted

const Driver = preload("res://tests/balance_tank_trace.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("passive tank elimination snapshots")
	var driver := Driver.new()
	driver._begin_ledger(4)
	var state := {"armor": [100, 0, 75, 50], "order": [1],
		"bodies": [{"slot": 1, "position": [1.0, 2.0, 3.0]}]}
	var original := state.duplicate(true)
	t.ok(driver._append_elimination(1, 4, state), "first elimination is recorded")
	t.equal(state, original, "snapshot does not mutate game state")
	t.equal(driver._eliminations[0]["slot"], 1, "victim slot is retained")
	t.equal(driver._eliminations[0]["place"], 4, "survival place is retained")
	state["armor"][0] = 0
	state["bodies"][0]["position"][0] = 100.0
	t.equal(driver._eliminations[0]["armor"][0], 100, "armor is an independent copy")
	t.equal(driver._eliminations[0]["bodies"][0]["position"][0], 1.0,
		"nested body coordinates are an independent copy")
	t.ok(not driver._append_elimination(1, 3, {}), "duplicate elimination is rejected")
	t.ok(not driver._append_elimination(-1, 3, {}), "negative victim is rejected")
	t.ok(not driver._append_elimination(4, 3, {}), "out-of-range victim is rejected")
	t.ok(not driver._append_elimination(0, 0, {}), "invalid place is rejected")
	t.ok(not driver._append_elimination(0, 5, {}), "out-of-range place is rejected")
	t.equal(driver._eliminations.size(), 1, "invalid events leave the ledger unchanged")
	driver._begin_ledger(4)
	t.equal(driver._eliminations.size(), 0, "next match clears previous snapshots")
	t.ok(driver._append_elimination(1, 4, original), "next match can record the same slot")
	t.ok(not EventBus.player_eliminated.is_connected(driver._record_elimination),
		"creating a driver does not subscribe to gameplay events")
	var config := MatchConfig.build("tank_arena", ["fanoos", "nabta", "ramla", "sakhra"], 0, 3, 510177)
	var scene: Node = load("res://src/match/match_scene.gd").new()
	host.add_child(scene)
	scene.setup({"config": config})
	scene.set_physics_process(false)
	for fighter in scene.ctx.fighters:
		fighter.set_physics_process(false)
	driver._observe_controller(scene.controller)
	driver._observe_controller(scene.controller)
	t.equal(driver._observed_controllers.size(), 1, "controller observation is idempotent")
	var shot := Projectile.new()
	shot.damage = 25.0
	scene.controller._on_hit(shot, 0, 1)
	t.equal(driver._hits.size(), 1, "an actual controller hit is observed exactly once")
	t.equal(driver._hits[0]["shooter"], 0, "actual shooter is recorded")
	t.equal(driver._hits[0]["victim"], 1, "actual victim is recorded")
	t.equal(driver._hits[0]["damage"], 25, "applied damage is recorded")
	t.equal(driver._hits[0]["armor_left"], 75, "remaining armor is post-hit")
	var rng_state: int = scene.ctx.rng.state
	var inputs := InputRouter.frame(0).encode()
	driver._record_damage(0, 1, 25, 75, scene.controller)
	t.equal(scene.ctx.rng.state, rng_state, "recording a hit does not advance gameplay RNG")
	t.equal(InputRouter.frame(0).encode(), inputs, "recording a hit does not publish input")
	var saved_position: Array = driver._hits[0]["bodies"][1]["position"].duplicate()
	scene.ctx.fighter(1).position += Vector3.ONE
	t.equal(driver._hits[0]["bodies"][1]["position"], saved_position, "hit positions are snapshots")
	shot.damage = 1000.0
	scene.controller._on_hit(shot, 0, 1)
	t.equal(driver._hits.back()["damage"], 75, "overkill records only remaining armor")
	t.equal(driver._hits.back()["armor_left"], 0, "lethal hit records zero armor")
	var hit_count := driver._hits.size()
	scene.controller._on_hit(shot, 0, 1)
	scene.controller._on_hit(shot, 0, 0)
	t.equal(driver._hits.size(), hit_count, "dead targets and self-hits do not emit damage events")
	driver._begin_ledger(4)
	t.equal(driver._hits.size(), 0, "next match clears hit history")
	t.equal(driver._observed_controllers.size(), 0, "next match removes old signal subscriptions")
	scene.controller._on_hit(shot, 0, 2)
	t.equal(driver._hits.size(), 0, "old controllers no longer write to the next match")
	shot.free()
	scene.teardown()
	scene.queue_free()
	driver.free()
	await host.get_tree().process_frame
