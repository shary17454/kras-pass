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
