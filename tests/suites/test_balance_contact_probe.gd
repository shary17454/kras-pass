extends RefCounted

class ClockProbe extends "res://tools/balance_contact_probe.gd":
	var tick_value := 1000
	func _physics_tick() -> int:
		return tick_value


func run(t: TestHarness) -> void:
	t.suite("development contact evidence")
	var probe := ClockProbe.new()
	var cfg := MatchConfig.build("sweeper_storm", ["nabta", "sakhra", "fanoos", "ramla"], 0, 1, 331)
	probe._begin_probe(cfg)
	t.equal(probe._contacts[0].get("accepted_jumps"), 0, "accepted jumps begin separately from input requests")
	t.ok(probe.has_method("_on_jump"), "probe records accepted movement events")
	if probe.has_method("_on_jump"):
		probe.call("_on_jump", 0)
		t.equal(probe._contacts[0].accepted_jumps, 0, "pre-round jumps cannot enter exposure evidence")
		probe._on_round_started(1)
		probe.call("_on_jump", 0)
		t.equal(probe._contacts[0].accepted_jumps, 1, "accepted event is distinct from a requested input")
		probe._on_eliminated(0, 4)
		probe.call("_on_jump", 0)
		t.equal(probe._contacts[0].accepted_jumps, 1, "eliminated player cannot extend accepted jumps")
		probe.call("_on_jump", -1)
		probe.call("_on_jump", 4)
		t.equal(probe._invalid_contacts, 2, "invalid jump slots are rejected as evidence")
		probe._begin_probe(cfg)
		t.equal(probe._contacts[0].accepted_jumps, 0, "new match clears accepted jumps")
	probe._on_contact(-1, 0, 8.0)
	probe._on_contact(1, 0, 3.0)
	probe._on_contact(-1, 0, 0.0)
	t.equal(probe._contacts[0].environment_hits, 1, "environment contacts are separate from rival contacts")
	t.equal(probe._contacts[0].player_hits, 1, "accepted rival hit is recorded")
	t.equal(probe._contacts[0].blocked_feedback, 1, "zero-push shield feedback is not an accepted impact")
	t.near(probe._contacts[0].environment_push, 8.0, 0.00001, "actual emitted environmental push is retained")
	t.near(probe._contacts[0].player_push, 3.0, 0.00001, "actual emitted rival push is retained")
	t.equal(probe._contacts[0].character, "nabta", "character attribution follows match roster rather than spawn number")
	for event in [[-1, -1, 1.0], [-1, 4, 1.0], [4, 0, 1.0], [-2, 0, 1.0], [-1, 0, NAN], [-1, 0, -1.0]]:
		probe._on_contact(event[0], event[1], event[2])
	t.equal(probe._invalid_contacts, 6, "malformed feedback is retained as invalid evidence, never a gameplay statistic")
	probe._begin_probe(cfg)
	t.equal(probe._contacts[0].environment_hits, 0, "new match cannot inherit previous contact counts")
	t.equal(probe._invalid_contacts, 0, "new match resets invalid-event count")
	probe._on_round_started(1)
	probe.tick_value += 2 * Engine.physics_ticks_per_second
	probe._on_eliminated(0, 4)
	t.near(probe._contacts[0].alive_seconds, 2.0, 0.00001, "elimination records simulation exposure rather than wall-clock duration")
	probe.tick_value += Engine.physics_ticks_per_second
	probe._on_eliminated(0, 4)
	t.near(probe._contacts[0].alive_seconds, 2.0, 0.00001, "duplicate elimination cannot extend exposure")
	var result := MatchResult.make("sweeper_storm", "sweeper_ring", [0, 1, 2, 3] as Array[int])
	result.duration = 8.0
	probe._on_round_finished(result)
	t.near(probe._contacts[1].alive_seconds, 8.0, 0.00001, "survivor exposure ends with actual round duration")
	t.near(probe._contacts[0].alive_seconds, 2.0, 0.00001, "completed round preserves eliminated player's exposure")
	t.ok(probe._round_complete, "results stop subsequent input sampling")
	probe.call("_on_jump", 1)
	t.equal(probe._contacts[1].accepted_jumps, 0, "results stop accepted-jump sampling")
	probe._begin_probe(cfg)
	t.ok(probe._contacts[0].alive_seconds == null and not probe._round_complete, "new round does not inherit exposure or completion")
	probe._probe_config = null
	probe.call("_on_jump", 0)
	t.equal(probe._contacts[0].accepted_jumps, 0, "late jump after cleanup cannot change evidence")
	probe._on_contact(-1, 0, 5.0)
	t.equal(probe._contacts[0].environment_hits, 0, "late feedback after match cannot mutate its evidence")
	probe.free()
