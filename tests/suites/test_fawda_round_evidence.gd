extends RefCounted

const Evidence = preload("res://tests/fawda_round_evidence.gd")


func run(t: TestHarness) -> void:
	t.suite("read-only fawda round evidence")
	var evidence := Evidence.new()
	var alive := [0, 2]
	var world := {"bombs": [{"fuse": 4.9}], "events": {"drop": {"sequence": 1}, "explode": {"sequence": 0}}}
	var saved := world.duplicate(true)
	t.ok(evidence.observe(0, MatchPhase.P.PLAYING, 2.1, alive, world), "first observed phase is reported")
	t.ok(not evidence.observe(0, MatchPhase.P.PLAYING, 2.2, alive, world), "same phase does not spam the log")
	t.equal(world, saved, "observer never changes bombs or feedback")
	alive.clear()
	t.equal(evidence.summary(0).alive, [0, 2], "alive list is copied, not retained by reference")
	world.bombs[0].fuse = 0.2
	world.events.explode.sequence = 1
	evidence.observe(0, MatchPhase.P.PLAYING, 6.8, [2], world)
	world.bombs.clear()
	world.events.explode.sequence = 0
	t.ok(evidence.observe(0, MatchPhase.P.FINISH, 6.8, [2], world), "terminal phase emits a summary")
	var row := evidence.summary(0)
	t.equal(row.events.explode, 1, "event evidence survives a later counter reset")
	t.near(row.minimum_fuse, 0.2, 0.001, "summary retains smallest actual observed fuse")
	t.equal(row.bombs, 0, "summary records live terminal bomb count")
	row.events.explode = 99
	t.equal(evidence.summary(0).events.explode, 1, "returned evidence cannot mutate stored observations")
	evidence.observe(1, MatchPhase.P.PLAYING, 0.0, [0, 2], {})
	t.equal(evidence.summary(1).events.size(), 0, "next round does not inherit old feedback")
	t.equal(evidence.summary(0).samples, 4, "only actual observations are counted")
	for sample in 1000:
		evidence.observe(1, MatchPhase.P.PLAYING, float(sample) / 60.0, [0, 2], {})
	t.equal(evidence.rounds.size(), 2, "memory is bounded by rounds, not frame count")
