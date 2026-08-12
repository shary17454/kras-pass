extends RefCounted
## Placement, ties, aggregation, survival ordering and tournament points.
## These are the numbers every mode depends on, so they are tested in isolation
## from any running match.


func run(t: TestHarness) -> void:
	t.suite("scoring")
	_places(t)
	_ties(t)
	_race_time(t)
	_aggregate(t)
	_survival(t)
	_tournament_points(t)


func _places(t: TestHarness) -> void:
	t.test("standard competition ranking")
	var p := MatchResult.compute_places([9, 4, 7, 1] as Array[int])
	t.equal(p[0], 1, "highest score is first")
	t.equal(p[2], 2, "second highest is second")
	t.equal(p[1], 3, "third")
	t.equal(p[3], 4, "lowest is last")


func _ties(t: TestHarness) -> void:
	t.test("ties share a place and skip the next")
	var p := MatchResult.compute_places([5, 5, 3, 1] as Array[int])
	t.equal(p[0], 1, "first tied player is 1st")
	t.equal(p[1], 1, "second tied player is also 1st")
	t.equal(p[2], 3, "next distinct score is 3rd, not 2nd")
	t.equal(p[3], 4, "last")

	t.test("four-way draw")
	var all := MatchResult.compute_places([2, 2, 2, 2] as Array[int])
	for i in 4:
		t.equal(all[i], 1, "everyone is first in a total draw")
	var r := MatchResult.make("x", "y", [2, 2, 2, 2] as Array[int])
	t.ok(r.is_draw(), "a four-way tie reports as a draw")
	t.equal(r.winners().size(), 4, "all four are winners")


func _race_time(t: TestHarness) -> void:
	t.test("race scoring inverts the comparison")
	var p := MatchResult.compute_places([1200, 900, 1500, 99999] as Array[int], false)
	t.equal(p[1], 1, "fastest time wins")
	t.equal(p[0], 2, "second fastest")
	t.equal(p[2], 3, "third")
	t.equal(p[3], 4, "unfinished runner is last")


func _aggregate(t: TestHarness) -> void:
	t.test("multi-round totals decide the match")
	var r1 := MatchResult.make("g", "a", [3, 1, 0, 0] as Array[int])
	var r2 := MatchResult.make("g", "a", [0, 4, 0, 0] as Array[int])
	var r3 := MatchResult.make("g", "a", [1, 0, 2, 0] as Array[int])
	var agg := MatchResult.aggregate("g", [r1, r2, r3] as Array[MatchResult])
	t.equal(agg.score_of(0), 4, "player 0 totals 4")
	t.equal(agg.score_of(1), 5, "player 1 totals 5")
	t.equal(agg.winner_slot(), 1, "highest total wins the match, not most rounds")
	t.equal(agg.rounds.size(), 3, "rounds are retained for the results screen")

	t.test("aggregate merges per-round details")
	r1.details[0]["knockouts"] = 2
	r2.details[0]["knockouts"] = 3
	var merged := MatchResult.aggregate("g", [r1, r2] as Array[MatchResult])
	t.equal(int(merged.detail(0, "knockouts", 0)), 5, "detail counters sum across rounds")


func _survival(t: TestHarness) -> void:
	t.test("survival ranks by elimination order")
	var ctx := MatchContext.new()
	ctx.config = MatchConfig.build("ring_rumble", ["nabta", "sakhra", "fanoos", "ramla"], 1, 1)
	ctx.alive = [true, true, true, true]
	ctx.scores = [0, 0, 0, 0]
	ctx.details = [{}, {}, {}, {}]
	ctx.eliminate(2)   # first out
	ctx.eliminate(0)   # second out
	ctx.eliminate(3)   # third out
	var s := ctx.survival_scores()
	t.greater(s[1], s[3], "last standing beats third out")
	t.greater(s[3], s[0], "third out beats second out")
	t.greater(s[0], s[2], "second out beats first out")
	var places := MatchResult.compute_places(s)
	t.equal(places[1], 1, "the survivor takes first place")
	t.equal(places[2], 4, "the first eliminated takes last")


func _tournament_points(t: TestHarness) -> void:
	t.test("tournament awards 5/3/2/1")
	var session := TournamentSession.new()
	var players: Array[PlayerConfig] = []
	for i in 4:
		var p := PlayerConfig.new()
		p.slot = i
		p.character_id = Registry.characters()[i].id
		players.append(p)
	session.setup(players, ["ring_rumble", "crate_smash"] as Array[String], 7)
	var r := MatchResult.make("ring_rumble", "vortex_ring", [10, 7, 4, 1] as Array[int])
	var awarded := session.award_for(r)
	t.equal(awarded[0], 5, "first place scores 5")
	t.equal(awarded[1], 3, "second scores 3")
	t.equal(awarded[2], 2, "third scores 2")
	t.equal(awarded[3], 1, "fourth scores 1")

	t.test("tied places share the combined award")
	var tied := MatchResult.make("ring_rumble", "vortex_ring", [10, 10, 4, 1] as Array[int])
	var shared := session.award_for(tied)
	t.equal(shared[0], shared[1], "tied players receive the same points")
	t.equal(shared[0], 4, "a shared first/second is worth ceil((5+3)/2)")

	t.test("session advances and crowns a champion")
	session.record(r)
	t.equal(session.index, 1, "recording a result advances the schedule")
	t.ok(not session.is_complete(), "two-game tournament is not done after one")
	session.record(MatchResult.make("crate_smash", "crate_yard", [0, 9, 0, 0] as Array[int]))
	t.ok(session.is_complete(), "schedule completes")
	t.equal(session.champion(), 1, "5+5 beats 5+... on total points")
	t.equal(session.rows().size(), 4, "standings list every competitor")

	t.test("random schedules do not repeat until the pool is exhausted")
	var games := TournamentSession.random_games(4, 42)
	t.equal(games.size(), 4, "requested game count is honoured")
	var seen := {}
	for g in games:
		seen[g] = true
	t.equal(seen.size(), 4, "no duplicates within one pass of the pool")
	t.equal(str(TournamentSession.random_games(4, 42)), str(games), "same seed gives the same schedule")
