extends RefCounted

func run(t: TestHarness, _host: Node) -> void:
	t.suite("rendered performance sampling budget")
	var probe: Node = load("res://tests/perf.gd").new()
	probe._samples.resize(400)
	probe._live_seconds = 2.0
	t.ok(not probe._sample_budget_met(), "fast rendering cannot substitute for simulation time")
	probe._live_seconds = 10.0
	t.ok(probe._sample_budget_met(), "ten live seconds and 400 rendered samples satisfy budget")
	probe._samples.resize(399)
	t.ok(not probe._sample_budget_met(), "simulation time alone cannot substitute for rendered samples")
	probe._samples.resize(400)
	probe._live_seconds = 9.999
	t.ok(not probe._sample_budget_met(), "minimum live duration is not rounded up")
	probe._samples.clear()
	probe._live_seconds = 0.5
	t.ok(probe._should_finish(true), "an early round ending never waits to fill the budget")
	t.ok(not probe._should_finish(false), "a live short sample continues below the wall ceiling")
	probe._elapsed = 24.999
	t.ok(not probe._should_finish(false), "wall ceiling is not rounded up")
	probe._elapsed = 25.0
	t.ok(probe._should_finish(false), "wall ceiling ends the probe without a full budget")
	probe.free()
