extends RefCounted

const Config = preload("res://tests/network_smoke_config.gd")


func run(t: TestHarness) -> void:
	t.suite("natural fawda final evidence")
	t.ok(Config.fawda_final_ended([0, 2], [2], 21.2166667), "recorded early survivor final is valid before any fuse must expire")
	t.ok(Config.fawda_round_ended([3], 19.85), "recorded four-player survivor is valid before explosion")
	t.ok(not Config.fawda_round_ended([0, 3], 19.85), "ordinary rounds cannot stop early with two alive")
	t.ok(not Config.fawda_final_ended([0, 2], [0, 2], 21.0), "two living contenders cannot end an unfinished final")
	t.ok(Config.fawda_final_ended([0, 2], [0, 2], 0.0), "real timeout permits a final draw")
	t.ok(Config.fawda_final_ended([0, 2], [0, 2], -0.01), "one-step clock overshoot is a real timeout")
	t.ok(not Config.fawda_final_ended([0, 2], [1], 0.0), "spectator cannot be the surviving player")
	t.ok(not Config.fawda_final_ended([0, 2], [0, 1, 2], 0.0), "timeout cannot retain an active spectator")
	t.ok(not Config.fawda_final_ended([], [2], 0.0), "ordinary matches do not use the final exception")
	t.ok(Config.fawda_final_ended([0, 2], [], 12.0), "simultaneous elimination is a natural terminal state")
	for invalid in [INF, -INF, NAN]:
		t.ok(not Config.fawda_final_ended([0, 2], [2], invalid), "invalid clocks are never completion evidence")
