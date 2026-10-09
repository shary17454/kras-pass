extends RefCounted


func run(t: TestHarness) -> void:
	t.suite("visual roster policy")
	var probe := load("res://tests/stage_zero_visual.gd")
	t.test("visual roster accepts all supported local human counts")
	for count in range(1, 5):
		t.equal(probe.parse_human_count(str(count)), count, "supported local roster is retained")
	t.test("invalid roster input cannot silently fall back to one human")
	for raw in ["", "0", "5", "-1", "1.5", "2.0", "nan", "all", "999999999"]:
		t.equal(probe.parse_human_count(raw), -1, "unsupported input is rejected: " + raw)
	t.test("visual capture matrix includes every declared arena without changing defaults")
	var cases: Array = probe.capture_cases(Registry.all_minigames(), PackedStringArray(), true)
	var expected := 0
	var seen := {}
	for game in Registry.all_minigames():
		expected += game.arena_ids.size()
	for capture in cases:
		var key: String = capture.game.id + "/" + capture.arena
		t.ok(not seen.has(key), "each game/arena pairing appears once")
		seen[key] = true
		t.ok(capture.arena in capture.game.arena_ids, "capture uses an arena declared by its game")
	t.equal(cases.size(), expected, "all declared pairings are captured")
	var defaults: Array = probe.capture_cases(Registry.all_minigames(), PackedStringArray(), false)
	t.equal(defaults.size(), Registry.all_minigames().size(), "default scope remains one arena per game")
	for capture in defaults:
		t.equal(capture.arena, capture.game.arena_ids[0], "default arena order is preserved")
	var selected := PackedStringArray(["sabaq_sawarikh"])
	var filtered: Array = probe.capture_cases(Registry.all_minigames(), selected, true)
	t.equal(filtered.size(), Registry.minigame("sabaq_sawarikh").arena_ids.size(), "game filter retains all of that game's arenas")
	for capture in filtered:
		t.equal(capture.game.id, "sabaq_sawarikh", "game filter excludes unrelated captures")
	t.test("arena filter reproduces exact affected pairings without changing the catalogue")
	var targeted: Array = probe.capture_cases(Registry.all_minigames(),
		PackedStringArray(["zone_hold", "sabaq_sawarikh"]), true, PackedStringArray(["dune_ring", "magma_ring"]))
	t.equal(targeted.size(), 2, "two affected pairings produce two capture cases")
	for capture in targeted:
		t.ok(capture.arena in ["dune_ring", "magma_ring"], "arena filter excludes unrelated maps")
	t.ok(probe.capture_cases(Registry.all_minigames(), PackedStringArray(["zone_hold"]), true,
		PackedStringArray(["magma_ring"])).is_empty(), "incompatible game and arena cannot yield an unrelated capture")
