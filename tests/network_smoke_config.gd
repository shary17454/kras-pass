extends RefCounted
## Keep ordinary boss fights at their authored duration, not the short fixture.

static func configure_boss(config: MatchConfig) -> void:
	if config.minigame_id in ["boss_forge", "boss_dreadnought", "boss_sovereign"]:
		config.duration_override = 0.0 if config.rule("online_contenders", []).is_empty() else 20.0
