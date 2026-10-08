extends RefCounted


func run(t: TestHarness) -> void:
	t.suite("development contact evidence")
	var probe = load("res://tools/balance_contact_probe.gd").new()
	var cfg := MatchConfig.build("sweeper_storm", ["nabta", "sakhra", "fanoos", "ramla"], 0, 1, 331)
	probe._begin_probe(cfg)
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
	probe._probe_config = null
	probe._on_contact(-1, 0, 5.0)
	t.equal(probe._contacts[0].environment_hits, 0, "late feedback after match cannot mutate its evidence")
	probe.free()
