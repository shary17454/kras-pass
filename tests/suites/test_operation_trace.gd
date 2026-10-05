extends RefCounted


func run(t: TestHarness) -> void:
	t.suite("bounded debug operation tracing")
	var trace := OperationTrace.new()
	trace.configure(false, true)
	t.equal(trace.begin(), 0, "release policy cannot activate clocks")
	trace.record("disabled", 1, 9000, 1, 1)
	t.ok(trace.report().costs.is_empty(), "release policy cannot collect records")
	trace.configure(true, false)
	t.equal(trace.begin(), 0, "debug builds require explicit opt-in")
	trace.configure(true, true)
	trace.record("ai", 100, 4099, 7, 9)
	t.equal(trace.report().slow_count, 0, "slow threshold is not rounded up")
	trace.record("ai", 100, 4100, 8, 10)
	t.equal(trace.report().slow_count, 1, "inclusive threshold records the actual interval")
	trace.record("bad", 10, 9, 1, 1)
	trace.record("bad", 0, 9, 1, 1)
	trace.record("", 1, 9, 1, 1)
	trace.record("x".repeat(65), 1, 9, 1, 1)
	t.equal(trace.report().costs.size(), 1, "invalid intervals and unbounded tags are excluded")
	for index in 20:
		trace.record("ai", 100, 5100 + index, 12, 13)
	var report := trace.report()
	t.equal(report.slow_count, 21, "all qualifying intervals are counted")
	t.equal(report.retained.size(), 8, "retained slow intervals are bounded")
	t.equal(report.retained[0].elapsed_usec, 5019, "worst interval is retained first")
	t.equal(report.retained[0].physics_frame, 12, "physics correlation uses supplied frame identity")
	t.equal(report.costs.ai.calls, 22, "aggregate counts include subthreshold intervals")
	report.costs.ai.calls = 0
	report.retained[0].tag = "mutated"
	t.equal(trace.report().costs.ai.calls, 22, "report cannot mutate internal aggregates")
	t.equal(trace.report().retained[0].tag, "ai", "report cannot mutate retained intervals")
	for index in 100:
		trace.record("tag%d" % index, 100, 101, 1, 1)
	t.equal(trace.report().costs.size(), 32, "aggregate tags are independently bounded")
	trace.reset()
	t.ok(trace.report().costs.is_empty() and trace.report().retained.is_empty(), "next probe resets all retained state")
	t.equal(trace.report().slow_count, 0, "next probe resets the slow count")
	trace.configure(false, true)
	trace.finish("disabled", 1)
	t.ok(trace.report().costs.is_empty(), "disabled finish is harmless")
