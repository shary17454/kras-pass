extends RefCounted

const Driver = preload("res://tests/balance_contact_trace.gd")


func run(t: TestHarness) -> void:
	t.suite("observational contact ledger")
	var driver := Driver.new()
	for slot in 4:
		driver._hits.append({"delivered": 0, "received": 0, "zero_strength": 0,
			"push_delivered": 0.0, "push_received": 0.0, "max_push_received": 0.0})
		driver._respawns.append(0)
	driver._record_hit(0, 1, 12.0)
	driver._record_hit(2, 1, 0.0)
	driver._record_hit(-1, 1, 4.0)
	t.equal(driver._hits[0]["delivered"], 1, "attacker gets one delivered event")
	t.equal(driver._hits[0]["push_delivered"], 12.0, "attacker push is retained")
	t.equal(driver._hits[1]["received"], 3, "environmental and shield events are recorded")
	t.equal(driver._hits[1]["zero_strength"], 1, "zero strength has its own count")
	t.equal(driver._hits[1]["push_received"], 16.0, "received push includes environment")
	t.equal(driver._hits[1]["max_push_received"], 12.0, "maximum is not sum")
	t.equal(driver._hits[2]["delivered"], 1, "zero strength is still an event")
	var before := driver._hits.duplicate(true)
	driver._record_hit(0, -1, 100.0)
	driver._record_hit(0, 4, 100.0)
	t.equal(driver._hits, before, "invalid victims do not alter the ledger")
	driver._record_respawn(3)
	driver._record_respawn(-1)
	driver._record_respawn(4)
	t.equal(driver._respawns, [0, 0, 0, 1], "respawn events only count valid slots")
	t.ok(not EventBus.player_hit.is_connected(driver._record_hit), "creating a driver does not subscribe")
	driver.free()
