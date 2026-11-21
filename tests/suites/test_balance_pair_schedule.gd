extends RefCounted

const Schedule = preload("res://tests/balance_pair_schedule.gd")
const Driver = preload("res://tests/balance_pair_sim.gd")


func run(t: TestHarness, host: Node) -> void:
	t.suite("supplementary pair-balanced schedule")
	var characters: Array[String] = ["a", "b", "c", "d", "e", "f", "g", "h"]
	for seed in [0, 1, 88000000, 1000000000]:
		var appearances := {}
		var seats := {}
		var pairs := {}
		var groups := [{}, {}]
		for id in characters:
			appearances[id] = 0
			seats[id] = [0, 0, 0, 0]
			pairs[id] = {}
			for other in characters:
				if id != other:
					pairs[id][other] = 0
		for index in 112:
			var roster := Schedule.roster_for(characters, index, seed)
			t.equal(roster.size(), 4, "quartet has four seats")
			t.equal(roster, Schedule.roster_for(characters, index, seed), "seeded roster is reproducible")
			var unique := {}
			for id in roster:
				unique[id] = true
			t.equal(unique.size(), 4, "no duplicate character in a match")
			var sorted: Array[String] = roster.duplicate()
			sorted.sort()
			var key := ",".join(sorted)
			var cycle := int(index / Schedule.CYCLE_LENGTH)
			groups[cycle][key] = int(groups[cycle].get(key, 0)) + 1
			for slot in 4:
				var id := roster[slot]
				appearances[id] += 1
				seats[id][slot] += 1
				for other in roster:
					if id != other:
						pairs[id][other] += 1
		for id in characters:
			t.equal(appearances[id], 56, "two cycles give every character equal exposure")
			t.equal(seats[id], [14, 14, 14, 14], "all seats have equal exposure")
			for other in characters:
				if id != other:
					t.equal(pairs[id][other], 24, "every opponent pair meets equally")
		for cycle in groups:
			t.equal(cycle.size(), 14, "each cycle has fourteen distinct quartets")
			for count in cycle.values():
				t.equal(count, 4, "each quartet rotates through four matches")
	var short: Array[String] = ["a", "b", "c", "d", "e", "f", "g"]
	t.ok(Schedule.roster_for(short, 0, 0).is_empty(), "non-eight-character catalog rejected")
	var duplicate: Array[String] = characters.duplicate()
	duplicate[7] = duplicate[0]
	t.ok(Schedule.roster_for(duplicate, 0, 0).is_empty(), "duplicate catalog rejected")
	duplicate[7] = " "
	t.ok(Schedule.roster_for(duplicate, 0, 0).is_empty(), "empty identity rejected")
	t.ok(Schedule.roster_for(characters, -1, 0).is_empty(), "negative match rejected")
	t.ok(Schedule.roster_for(characters, 0, -1).is_empty(), "negative seed rejected")
	for count in [56, 112, 168]:
		var driver := Driver.new()
		t.ok(driver._parse_args(PackedStringArray(["--runs=%d" % count, "--only=duel_pit"])),
			"complete diagnostic cycles accepted")
		driver.free()
	for arguments in [["--runs=55"], ["--runs=57"], ["--runs=0"],
			["--runs=56", "--balanced-rosters"], ["--runs=56", "--clipped-rounds"]]:
		var driver := Driver.new()
		t.ok(not driver._parse_args(PackedStringArray(arguments)), "incomplete or incompatible diagnostic rejected")
		driver.free()
	await host.get_tree().process_frame
