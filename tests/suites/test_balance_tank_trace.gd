extends RefCounted

const Driver = preload("res://tests/balance_tank_trace.gd")


func run(t: TestHarness) -> void:
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
	driver.free()
