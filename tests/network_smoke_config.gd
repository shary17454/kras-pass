extends RefCounted
## Keep ordinary boss fights at their authored duration, not the short fixture.

static func kart_deadline(tournament: bool) -> int:
	var budget: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/race_smoke_budget.json"))
	var seconds := int(budget.setup_seconds)
	if tournament:
		seconds += int(budget.tournament_races) * int(budget.race_seconds)
		seconds += int(budget.maximum_finals) * int(budget.final_seconds)
	else:
		seconds += int(budget.ordinary_races) * int(budget.race_seconds)
	return seconds


static func configure_boss(config: MatchConfig) -> void:
	if config.minigame_id in ["boss_forge", "boss_dreadnought", "boss_sovereign", "boss_colossus"]:
		config.duration_override = 0.0 if config.rule("online_contenders", []).is_empty() else 20.0


static func configure_lab(config: MatchConfig) -> void:
	if config.minigame_id == "lab_crates":
		config.duration_override = 0.0


static func lab_deadline(tournament: bool) -> int:
	var budget: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/lab_smoke_budget.json"))
	var matches := int(budget.tournament_matches) + int(budget.maximum_finals) if tournament else 1
	return int(budget.setup_seconds) + matches * int(budget.rounds_per_match) * int(budget.round_seconds)


static func configure_crate(config: MatchConfig) -> void:
	if config.minigame_id == "crate_smash":
		config.duration_override = 0.0


static func crate_deadline(tournament: bool) -> int:
	var budget: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/crate_smoke_budget.json"))
	var matches := int(budget.tournament_matches) + int(budget.maximum_finals) if tournament else 1
	return int(budget.setup_seconds) + matches * int(budget.rounds_per_match) * int(budget.round_seconds)


static func siege_evidence(hit: bool, destroyed: bool, contenders: Array, scores: Array) -> bool:
	if not hit:
		return false
	if contenders.is_empty():
		return destroyed
	var scored := false
	for slot in contenders:
		if not slot is int or slot < 0 or slot >= scores.size():
			return false
		var score = scores[slot]
		if (not score is int and not score is float) or not is_finite(float(score)):
			return false
		scored = scored or float(score) > 0.0
	return scored


static func fawda_final_ended(contenders: Array, alive: Array, time_left: float) -> bool:
	if contenders.is_empty() or not is_finite(time_left):
		return false
	for slot in alive:
		if not contenders.has(slot):
			return false
	return fawda_round_ended(alive, time_left)


static func fawda_round_ended(alive: Array, time_left: float) -> bool:
	return is_finite(time_left) and (alive.size() <= 1 or time_left <= 0.0)
