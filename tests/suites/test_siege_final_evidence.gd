extends RefCounted

const Config = preload("res://tests/network_smoke_config.gd")


func run(t: TestHarness) -> void:
	t.suite("siege final evidence")
	t.ok(Config.siege_evidence(true, true, [], [2, 0, 0, 0]), "ordinary damage and destruction accepted")
	t.ok(not Config.siege_evidence(true, false, [], [2, 0, 0, 0]), "ordinary damage without destruction rejected")
	t.ok(not Config.siege_evidence(false, true, [], [2, 0, 0, 0]), "ordinary destruction without hit evidence rejected")
	t.ok(Config.siege_evidence(true, false, [2, 3], [0, 0, 3, 0]), "short final accepts actual contender score without destruction")
	t.ok(not Config.siege_evidence(true, false, [2, 3], [3, 0, 0, 0]), "spectator score cannot qualify final")
	t.ok(not Config.siege_evidence(false, true, [2, 3], [0, 0, 3, 0]), "final score without actual hit rejected")
	t.ok(not Config.siege_evidence(true, true, [2, 3], [0, 0, 0, 0]), "zero-score final rejected even with destruction")
	t.ok(not Config.siege_evidence(true, false, [2, 4], [0, 0, 3, 0]), "out-of-range contender rejected")
	t.ok(not Config.siege_evidence(true, false, [-1, 2], [0, 0, 3, 0]), "negative contender rejected")
	t.ok(not Config.siege_evidence(true, false, [2.5], [0, 0, 3, 0]), "fractional contender rejected")
	t.ok(not Config.siege_evidence(true, false, [2], [0, 0, NAN, 0]), "nonfinite score rejected")
	t.ok(not Config.siege_evidence(true, false, [2], [0, 0, "3", 0]), "string score rejected")
