extends RefCounted


func run(t: TestHarness, host: Node) -> void:
	t.suite("effective character movement and combat budget")
	var neutral := Fighter.new()
	neutral.data = CharacterData.new()
	neutral._apply_character()
	var fields := ["top_speed", "acceleration", "jump_velocity", "knock_resist", "knock_power", "turn_rate", "air_control"]
	for character in Registry.characters():
		var fighter := Fighter.new()
		fighter.data = character
		fighter._apply_character()
		for field in fields:
			var ratio := float(fighter.get(field)) / float(neutral.get(field))
			t.ok(ratio >= 0.85 - 0.00001 and ratio <= 1.15 + 0.00001, "%s effective %s including its perk stays within 15 percent" % [character.id, field])
		fighter.free()
	# Character balance must not quietly alter the established neutral handling.
	var expected := {"top_speed": 9.1, "acceleration": 56.0, "jump_velocity": 9.8,
		"knock_resist": 1.1, "knock_power": 1.08, "turn_rate": 12.5, "air_control": 0.49}
	for field in fields:
		t.near(float(neutral.get(field)), float(expected[field]), 0.0001, "neutral %s is preserved" % field)
	neutral.free()
	await host.get_tree().process_frame
