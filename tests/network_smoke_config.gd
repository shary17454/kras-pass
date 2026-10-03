extends RefCounted
## Keep ordinary boss fights at their authored duration, not the short fixture.

static func configure_boss(config: MatchConfig) -> void:
	if config.minigame_id in ["boss_forge", "boss_dreadnought", "boss_sovereign", "boss_colossus"]:
		config.duration_override = 0.0 if config.rule("online_contenders", []).is_empty() else 20.0


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
