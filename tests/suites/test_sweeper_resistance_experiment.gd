extends RefCounted


func run(t: TestHarness) -> void:
	t.suite("counterfactual resistance isolation")
	var probe = load("res://tests/sweeper_resistance_experiment.gd").new()
	t.ok(probe._parse_args(["--only=sweeper_storm", "--runs=64"]), "experiment requires the intended game")
	t.ok(not probe._parse_args(["--only=ring_brawl"]), "experiment cannot mutate another minigame")
	t.ok(not probe._parse_args(["--only=sweeper_storm", "--clipped-rounds"]), "experiment cannot silently shorten rounds")
	var neutral := Fighter.new()
	neutral.data = CharacterData.new()
	neutral._apply_character()
	for character in Registry.characters():
		var fighter := Fighter.new()
		fighter.data = character
		fighter._apply_character()
		var fields := ["top_speed", "acceleration", "jump_velocity", "knock_power", "turn_rate", "air_control", "health"]
		var before := {}
		for field in fields:
			before[field] = fighter.get(field)
		probe._neutralize_resistance(fighter)
		t.near(fighter.knock_resist, neutral.knock_resist, 0.00001, "only resistance is neutralized")
		for field in fields:
			t.equal(fighter.get(field), before[field], "%s %s is unchanged" % [character.id, field])
		fighter.free()
	var report := {"simulation_source_start": "source", "simulation_source_end": "source",
		"engine_version": Engine.get_version_info().string, "sample_mode": probe.SAMPLE_MODE}
	var sample := {"sample_mode": probe.SAMPLE_MODE, "attempted_runs": 64, "runs": 64,
		"difficulty_attempted": 32, "difficulty_completed": 32,
		"difficulty_pairing": "matched_seed_character", "flags": []}
	t.ok(probe.Evidence.problems(report, sample, "source").has("natural round evidence required"),
		"counterfactual sample cannot qualify as natural release evidence")
	neutral.free()
	probe.free()
