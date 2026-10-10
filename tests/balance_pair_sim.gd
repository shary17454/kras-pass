extends "res://tools/balance_sim.gd"
## Supplementary natural-duration diagnostic. Use complete 56-match cycles.
## Same gameplay, difficulty comparisons and thresholds as balance_sim.gd.

const Schedule = preload("res://tests/balance_pair_schedule.gd")


func _init() -> void:
	runs = Schedule.CYCLE_LENGTH


func _parse_args(arguments: PackedStringArray) -> bool:
	if not super._parse_args(arguments):
		return false
	return Registry.characters().size() == 8 and runs % Schedule.CYCLE_LENGTH == 0 \
		and not balanced_rosters and natural_rounds


func _baseline_roster(run: int) -> Array[String]:
	var characters: Array[String] = []
	for character in Registry.characters():
		characters.append(character.id)
	return Schedule.roster_for(characters, run, _baseline_seed(0))


func _simulate(definition: MiniGameDef) -> Dictionary:
	var row: Dictionary = await super._simulate(definition)
	row["roster_policy"] = "pair_balanced_affine_plane_rotation"
	row["pair_schedule"] = {"cycle_length": Schedule.CYCLE_LENGTH,
		"appearances_per_cycle": 28, "appearances_per_seat_per_cycle": 7,
		"pair_coappearances_per_cycle": 12}
	return row
