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
	var neutral_drive := Fighter.new()
	neutral_drive.data = CharacterData.new()
	neutral_drive.locomotion = Fighter.Locomotion.DRIVE
	neutral_drive._apply_character()
	var neutral_angle := _drive_angle(neutral_drive)
	t.near(neutral_angle, 3.1 * (0.35 + 0.65 * 0.75) * 0.1, 0.00001, "neutral vehicle steering is preserved")
	for character in Registry.characters():
		var vehicle := Fighter.new()
		vehicle.data = character
		vehicle.locomotion = Fighter.Locomotion.DRIVE
		vehicle._apply_character()
		var angle := _drive_angle(vehicle)
		var expected_ratio := vehicle.turn_rate / neutral_drive.turn_rate
		t.near(angle / neutral_angle, expected_ratio, 0.00001, "%s vehicle applies handling including its turn perk" % character.id)
		t.ok(angle / neutral_angle >= 0.85 and angle / neutral_angle <= 1.15, "%s vehicle steering stays within its effective budget" % character.id)
		for field in ["top_speed", "acceleration"]:
			var ratio := float(vehicle.get(field)) / float(neutral_drive.get(field))
			t.ok(ratio >= 0.85 - 0.00001 and ratio <= 1.15 + 0.00001, "%s vehicle %s stays within its effective budget" % [character.id, field])
		var speed_ratio := vehicle.top_speed / neutral_drive.top_speed
		t.ok(speed_ratio >= 0.94 and speed_ratio <= 1.06, "%s vehicle cruising speed leaves room for combat and handling tradeoffs" % character.id)
		var tuning: Dictionary = Balance.table("tuning").get("fighter", {})
		var neutral_speed := float(tuning.base_speed) + float(tuning.speed_range) * 0.5
		var expected_speed := (neutral_speed + float(tuning.speed_range) * (character.speed - 0.5) * 0.35) * float(tuning.drive_speed_mult)
		t.near(vehicle.top_speed, expected_speed, 0.0001, "%s vehicle retains a bounded nonzero character speed difference" % character.id)
		vehicle.free()
	neutral_drive.free()
	await host.get_tree().process_frame


func _drive_angle(fighter: Fighter) -> float:
	fighter._steer = 0.0
	fighter.velocity = Vector3(0.0, 0.0, fighter.top_speed * 0.75)
	fighter._integrate_drive(Vector3(1.0, 0.0, -1.0), 0.1)
	return absf(fighter._steer)
