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
	probe._record_slow_frame(24.999, {})
	probe._record_slow_frame(NAN, {})
	probe._record_slow_frame(INF, {})
	t.equal(probe._slow_frame_count, 0, "trace excludes normal and non-finite frame times")
	var measurements := {"scores": [1, 2]}
	for index in 20:
		probe._record_slow_frame(25.0 + index, measurements)
	measurements.scores[0] = 999
	t.equal(probe._slow_frame_count, 20, "trace counts every slow frame without retaining all samples")
	t.equal(probe._slow_frames.size(), 8, "trace memory remains bounded to eight frames")
	t.equal(probe._slow_frames[0].frame_ms, 44.0, "trace retains the worst interval first")
	t.equal(probe._slow_frames[7].frame_ms, 37.0, "trace retains the eight worst intervals")
	t.equal(probe._slow_frames[0].scores[0], 1, "later game state cannot mutate captured trace evidence")
	probe.free()
